module

public meta import Lean
public meta import MetaBench.Core

/-!
# The `#benchmark` command.

The `#benchmark` command is used to benchmark elaboration, proof construction, and kernel time for
`theorem` or `example` declarations. It reports the total wall-clock time and heartbeat cost of all
three phases.

```
/--
info: example:
phase    kHB     min…max   ms   min…max
goal   25.55 25.48…25.57 0.52 0.51…0.63
proof   1.07   1.07…1.09 0.03 0.03…0.05
kernel  0.89   0.89…0.89 0.05 0.05…0.07
total  27.52 27.44…27.52 0.60 0.59…0.74
proof term: 56 nodes, kernel 916 ns/node
-/
#guard_msgs in
#benchmark in
example : (2 : Nat) ^ 10 = 1024 := by decide
```
-/

open Lean Elab Command Term Meta

namespace MetaBench

/-- `benchmark` "name" binders* : goal := proof` elaborates the goal and the proof, builds a
theorem, passes it to the kernel for checking, and logs the result. -/
syntax (name := benchmarkCmd)
  "#benchmark" (ppSpace str)? " in" ppLine Lean.Parser.Command.declaration : command

meta register_option bench.iters : Nat := {
  defValue := 5
  descr := "#benchmark: number of iterations per benchmark"
}

meta def elabGoal (stx : Syntax) : TermElabM Expr := do
  let goal ← Term.elabType stx
  Term.synthesizeSyntheticMVarsNoPostponing
  instantiateMVars goal

meta def elabProof (stx : Syntax) (goal : Expr) : TermElabM Expr := do
  let proof ←
    match stx with
    | `(by $tac) =>
      let mvar ← mkFreshExprMVar goal (kind := .syntheticOpaque)
      let remainingGoals ← Tactic.run mvar.mvarId! (Tactic.evalTactic tac)
      unless remainingGoals.isEmpty do
        throwError "unsolved goals: {MessageData.ofGoal <$> remainingGoals}"
      pure mvar
    | _ => Term.elabTermEnsuringType stx goal
  Term.synthesizeSyntheticMVarsNoPostponing
  instantiateMVars proof

/-- Package `goal` and `proof` into a theorem. -/
meta def mkTheorem (name : Name) (fvars : Array Expr) (goal proof : Expr) :
    TermElabM TheoremVal := do
    if proof.hasSorry then
      throwError "benchmark proof contains sorry"
    let type ← Term.levelMVarToParam (← mkForallFVars fvars goal)
    let value ← Term.levelMVarToParam (← mkLambdaFVars fvars proof)
    if type.hasExprMVar || value.hasExprMVar then
      throwError "benchmark contains metavariables"
    if type.hasFVar || value.hasFVar then
      throwError "benchmark uses section variables.\
        You must write the variable bindings on the benchmark instead"
    let levelParams := (collectLevelParams (collectLevelParams {} type) value).params.toList
    return { name, levelParams, type, value }

/-- Pass `thm` for kernel checking. -/
meta def kernelCheck (thm : TheoremVal) : TermElabM Unit := do
  let decl := Declaration.thmDecl thm
  let kenv := (← getEnv).toKernelEnv
  let opts ← getOptions
  -- Wrap `addDecl` in `IO.lazyPure` to force evaluation even though the result is unused.
  match ← IO.lazyPure fun _ => kenv.addDecl opts decl none with
  | .ok _ => pure ()
  | .error ex => throwKernelException ex

/-- Block until every kernel check queued by earlier commands has finished -/
meta def awaitPendingKernelChecks : CoreM Unit := do
  let env ← getEnv
  discard <| IO.lazyPure fun _ => env.toKernelEnv

structure Spec where
  addDecl? : Bool
  declName : Name
  levelNames : List Name
  binders : Array Syntax
  goal : Syntax
  proof : Syntax

meta def Spec.label (spec : Spec) : String :=
  if spec.addDecl?
    then (privateToUserName spec.declName).toString
    else "example"

/-- Sample all phases of a single theorem. Returns the `PhaseSamples` and the checked theorem. -/
meta def samplePhases (spec : Spec) : TermElabM (PhaseSamples × TheoremVal) :=
  Term.withoutErrToSorry <| Term.withDeclName spec.declName <| Term.withLevelNames spec.levelNames do
    let s0 ← Sample.now
    Term.elabBinders spec.binders fun fvars => do
      let goal ← elabGoal spec.goal
      let s1 ← Sample.now
      let proof ← elabProof spec.proof goal
      let thm ← mkTheorem spec.declName fvars goal proof
      let s2 ← Sample.now
      kernelCheck thm
      let s3 ← Sample.now
      let phases := fun
        | .goal => s1.sub s0
        | .proof => s2.sub s1
        | .kernel => s3.sub s2
      return (phases, thm)

/-- How one iteration ended. `dnf` is data (a resource limit was hit); `fail` is breakage. -/
inductive SampleResult where
  | ok (samples : PhaseSamples) (thm : TheoremVal)
  | dnf (message : String)
  | fail (message : String)

/-- One iteration under the ambient `maxHeartbeats`, restarted for each (Lean counts it per command). -/
meta def runSample (spec : Spec) : TermElabM SampleResult :=
  Core.withCurrHeartbeats <|
  tryCatchRuntimeEx
    (do
      let (samples, thm) ← samplePhases spec
      return .ok samples thm)
    fun e => do
      let message ← e.toMessageData.toString
      -- TODO: Make kernel timeout detection more robust
      let kernelTimeout := message.startsWith "(kernel) deterministic timeout"
      return if e.isRuntime || kernelTimeout then .dnf message else .fail message

inductive BenchResult where
  | ok (iterations : Array PhaseSamples) (thm : TheoremVal)
  -- benchmark did not finish
  | dnf (message : String)
  | fail (message : String)

meta def runBenchmark (spec : Spec) : TermElabM BenchResult := do
  let opts ← getOptions
  let iters := bench.iters.get opts
  awaitPendingKernelChecks

  -- warmup
  let messages := (← getThe Core.State).messages
  let info ← getInfoState
  let thm ← match ← runSample spec with
    | .ok _ d => pure d
    | .dnf message => return .dnf message
    | .fail message => return .fail message
  modifyThe Core.State fun s => {s with messages}
  setInfoState info

  let mut samples : Array PhaseSamples := #[]
  for _ in [0:iters] do
    match ← withoutModifyingState (runSample spec) with
    | .ok ps _ =>
      samples := samples.push ps
    | .dnf message => return .dnf message
    | .fail message => return .fail message
  return .ok samples thm

meta def parseDecl (decl : TSyntax ``Parser.Command.declaration) : CommandElabM Spec := do
  let (theoremId?, binders, goal?, val) ← match decl with
    | `($_:declModifiers theorem $id:declId $sig:declSig $val:declVal) =>
      let (binders, goal) := expandDeclSig sig
      pure (some id, binders, some goal, val)
    | `($_:declModifiers example $sig:optDeclSig $val:declVal) =>
      let (binders, goal?) := expandOptDeclSig sig
      pure (none, binders, goal?, val)
    | _ => throwErrorAt decl "#benchmark supports `theorem` and `example` only"
  let some goal := goal?
    | throwErrorAt decl "#benchmark: the benchmark needs a type"
  let proof ← match val with
    | `(Parser.Command.declValSimple| := $body) => pure body.raw
    | _ => throwErrorAt val "#benchmark: the proof must be a plain `:= proof`"
  let (addDecl?, declName, levelNames) ←
    match theoremId? with
    | some id =>
      let r ← liftTermElabM <|
        Term.expandDeclId (← getCurrNamespace) (← getScope).levelNames id {}
      pure (true, r.declName, r.levelNames)
    | none =>
      pure (false, ← liftCoreM mkFreshId, (← getScope).levelNames)
  return { addDecl?, declName, levelNames, binders := binders.getArgs, goal, proof }

@[command_elab benchmarkCmd]
public meta def elabBenchmarkCmd : CommandElab := fun stx => do
  let `(#benchmark $[$label?:str]? in $decl:declaration) := stx
    | throwUnsupportedSyntax
  let spec ← parseDecl decl
  let label := (label?.map (·.getString)).getD spec.label
  withScope (fun s => { s with opts := Elab.async.set s.opts false }) do
  runTermElabM fun _ => do
    match ← runBenchmark spec with
    | .ok iterations thm =>
      if spec.addDecl? then
        withOptions (debug.skipKernelTC.set · true) <| addDecl (.thmDecl thm)
      -- The number of distinct subterms nodes in the proof.
      let nodes ← (ShareCommon.shareCommon thm.value).numObjs
      logInfo m!"{label}:\n{renderReport iterations nodes}"
    | .dnf message => logInfo m!"{label}: dnf: {(message.splitOn "\n").headD message}"
    | .fail message => logError message

end MetaBench
