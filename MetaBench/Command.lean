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
goal   25.49 25.42…25.51 0.83 0.82…0.88
proof   1.07   1.07…1.09 0.05 0.05…0.06
kernel  0.88   0.88…0.88 0.10 0.07…0.14
total  27.46 27.38…27.46 0.98 0.94…1.05
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
    TermElabM Declaration := do
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
    return .thmDecl { name, levelParams, type, value }

/-- Pass `decl` for kernel checking. -/
meta def kernelCheck (decl : Declaration) : TermElabM Unit := do
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
meta def samplePhases (spec : Spec) : TermElabM (PhaseSamples × Declaration) :=
  Term.withoutErrToSorry <| Term.withDeclName spec.declName <| Term.withLevelNames spec.levelNames do
    let s0 ← Sample.now
    Term.elabBinders spec.binders fun fvars => do
      let goal ← elabGoal spec.goal
      let s1 ← Sample.now
      let proof ← elabProof spec.proof goal
      let decl ← mkTheorem spec.declName fvars goal proof
      let s2 ← Sample.now
      kernelCheck decl
      let s3 ← Sample.now
      let phases := fun
        | .goal => s1.sub s0
        | .proof => s2.sub s1
        | .kernel => s3.sub s2
      return (phases, decl)

/-- How one iteration ended. `dnf` is data (a resource limit was hit); `fail` is breakage. -/
inductive SampleResult where
  | ok (samples : PhaseSamples) (decl : Declaration)
  | fail (message : String)

meta def runSample (spec : Spec) : TermElabM SampleResult :=
  tryCatchRuntimeEx
    (do
      let (samples, decl) ← samplePhases spec
      return .ok samples decl)
    fun e => do
      let message ← e.toMessageData.toString
      return .fail message

inductive BenchResult where
  | ok (iterations : Array PhaseSamples) (decl : Declaration)
  | fail (message : String)

meta def runBenchmark (spec : Spec) : TermElabM BenchResult := do
  let opts ← getOptions
  let iters := bench.iters.get opts
  awaitPendingKernelChecks

  -- warmup
  let messages := (← getThe Core.State).messages
  let info ← getInfoState
  let decl ← match ← runSample spec with
    | .ok _ d => pure d
    | .fail message => return .fail message
  modifyThe Core.State fun s => {s with messages}
  setInfoState info

  let mut samples : Array PhaseSamples := #[]
  for _ in [0:iters] do
    match ← withoutModifyingState (runSample spec) with
    | .ok ps _ =>
      samples := samples.push ps
    | .fail message => return .fail message
  return .ok samples decl

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
    | .ok iterations decl =>
      if spec.addDecl? then
        withOptions (debug.skipKernelTC.set · true) <| addDecl decl
      logInfo m!"{label}:\n{renderIterations iterations}"
    | .fail message => logError message

end MetaBench
