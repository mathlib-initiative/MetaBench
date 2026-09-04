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
goal   27.29 kHB 1.30 ms
proof   3.72 kHB 0.58 ms
kernel  0.93 kHB 0.16 ms
total  31.94 kHB 2.04 ms
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
    awaitPendingKernelChecks
    let (phases, decl) ← samplePhases spec
    if spec.addDecl? then
      withOptions (debug.skipKernelTC.set · true) <| addDecl decl
    logInfo m!"{label}:\n{phases.render}"

end MetaBench
