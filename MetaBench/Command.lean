module

public meta import Lean
public meta import MetaBench.Core
meta import Std.Time

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

When `bench.out` is set to a file path each benchmark run also appends a JSON object to the file:
the label, the run's start time, the `bench.tag` option, the Lean version, the source file and line,
the options in force, the node counts of the proof and the statement, the proof's head constants,
the kernel's unfold counts, and the raw samples of the warmup and of every iteration.

When `bench.proofHeads n` is set the report also lists the `n` most frequent head constants of the proof
term.

When `bench.kernelUnfolds n` is set the report also lists the `n` most frequently unfolded
declarations during kernel checking.
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

meta register_option bench.out : String := {
  defValue := ""
  descr := "#benchmark: if set, append the benchmark output to a file at this path"
}

meta register_option bench.proofHeads : Nat := {
  defValue := 0
  descr := "#benchmark: list the n most frequent head constants of the proof term (0: off)"
}

meta register_option bench.kernelUnfolds : Nat := {
  defValue := 0
  descr := "#benchmark: list the n most frequent declarations the kernel unfolded (0: off)"
}

meta register_option bench.tag : String := {
  defValue := ""
  descr := "#benchmark: a tag recorded with the JSON output, e.g. a git revision"
}

/-- The start time of this process, so every benchmark of one run carries the same `run` stamp. -/
meta initialize runStamp : String ←
  return (Std.Time.DateTime.ofTimestamp (← Std.Time.Timestamp.now) .UTC).toISO8601String

/-- The options in force, as a JSON object. -/
meta def optionsJson (opts : Options) : Json := Id.run do
  let mut fields := []
  for (name, value) in opts do
    fields := (name.toString, match value with
      | .ofString v => toJson v
      | .ofBool v => toJson v
      | .ofName v => toJson v.toString
      | .ofNat v => toJson v
      | .ofInt v => toJson v
      | .ofSyntax v => toJson v.prettyPrint.pretty) :: fields
  return Json.mkObj fields

/-- The number of distinct subterms of `e` headed by each constant: an application counts once under
its head, a bare constant under itself, and every subterm at most once. -/
meta partial def headConstants (e : Expr) : Std.TreeMap String Nat compare :=
  ((go e).run ({}, {})).2.2
where
  go (e : Expr) : StateM (Std.HashSet Expr × Std.TreeMap String Nat compare) Unit := do
    if (← get).1.contains e then return
    modify fun (seen, counts) => (seen.insert e, counts)
    let count (n : Name) : StateM (Std.HashSet Expr × Std.TreeMap String Nat compare) Unit :=
      modify fun (seen, counts) => (seen, counts.insert n.toString (counts.getD n.toString 0 + 1))
    match e with
    | .app .. =>
      match e.getAppFn with
      | .const n _ => count n
      | fn => go fn
      e.getAppArgs.forM go
    | .const n _ => count n
    | .lam _ t b _ | .forallE _ t b _ => go t; go b
    | .letE _ t v b _ => go t; go v; go b
    | .mdata _ b | .proj _ _ b => go b
    | _ => pure ()

/-- `after - before` per declaration, as a name-keyed map without zero entries. -/
meta def counterDiff (before after : PHashMap Name Nat) : Std.TreeMap String Nat compare :=
  after.foldl (init := {}) fun m n c =>
    let c := c - (before.find? n).getD 0
    if c == 0 then m else m.insert n.toString c

/-- Return a frequency table recording the number of times the kernel unfolds each declaration when
checking `thm`. -/
meta def checkUnfolds (thm : TheoremVal) : TermElabM (Std.TreeMap String Nat compare) := do
  let kenv := ((← getEnv).toKernelEnv.enableDiag true).resetDiag
  let opts ← getOptions
  match ← IO.lazyPure fun _ => kenv.addDecl opts (.thmDecl thm) none with
  | .ok kenv => return counterDiff {} kenv.diagnostics.unfoldCounter
  | .error ex => throwKernelException ex

meta def emitJson (json : Json) : CoreM Unit := do
  let path := bench.out.get (← getOptions)
  unless path.isEmpty do
    IO.FS.withFile path .append fun h => h.putStrLn json.compress

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

/-- One iteration under the ambient `maxHeartbeats`. -/
meta def runSample (spec : Spec) : TermElabM (PhaseSamples × TheoremVal) :=
  Core.withCurrHeartbeats (samplePhases spec)

structure BenchRun where
  thm : TheoremVal
  warmup : PhaseSamples
  iters : Array PhaseSamples
  /-- The kernel's unfolds for the declarations the warmup added, e.g. `decide +kernel`'s lemmas. -/
  auxUnfolds : Std.TreeMap String Nat compare

meta def runBenchmark (spec : Spec) : TermElabM BenchRun := do
  let iters := bench.iters.get (← getOptions)
  awaitPendingKernelChecks

  -- warmup: commit the caches, discard its messages and info. It runs with `diagnostics` on in
  -- order to count declaration unfolding.
  let messages := (← getThe Core.State).messages
  let info ← getInfoState
  let initEnv ← getEnv
  let (warmup, thm) ← tryFinally (withOptions (diagnostics.set · true) (runSample spec))
    (modifyEnv (Kernel.enableDiag · (Kernel.isDiagnosticsEnabled initEnv)))
  let auxUnfolds := counterDiff (Kernel.getDiagnostics initEnv).unfoldCounter
    (Kernel.getDiagnostics (← getEnv)).unfoldCounter
  modifyThe Core.State fun s => { s with messages }
  setInfoState info

  let mut samples : Array PhaseSamples := #[]
  for _ in [0:iters] do
    let (ps, _) ← withoutModifyingState (runSample spec)
    samples := samples.push ps
  return { thm, warmup, iters := samples, auxUnfolds }

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
    let { thm, warmup, iters := iterations, auxUnfolds } ← runBenchmark spec
    -- Before the declaration is added: the diagnostic check adds it to a kernel environment again.
    let kernelUnfolds := (← checkUnfolds thm).foldl (fun m n c => m.insert n (m.getD n 0 + c)) auxUnfolds
    if spec.addDecl? then
      withOptions (debug.skipKernelTC.set · true) <| addDecl (.thmDecl thm)
    -- Share equal subterms first, so the counts are of distinct subterms.
    let value := ShareCommon.shareCommon thm.value
    let opts ← getOptions
    let report : Report := {
      label, run := runStamp, tag := bench.tag.get opts
      file := ← getFileName, line := ((← getFileMap).toPosition (stx.getPos?.getD 0)).line
      options := optionsJson opts
      proofNodes := ← value.numObjs, typeNodes := ← (ShareCommon.shareCommon thm.type).numObjs
      proofHeads := headConstants value, kernelUnfolds
      warmup, iters := iterations }
    let proofHeads := bench.proofHeads.get opts
    let unfolds := bench.kernelUnfolds.get opts
    logInfo m!"{label}:\n{renderReport report}\
      {if proofHeads == 0 then "" else "\n\n" ++ renderProofHeads report proofHeads}\
      {if unfolds == 0 then "" else "\n\n" ++ renderKernelUnfolds report unfolds}"
    emitJson (toJson report)

end MetaBench
