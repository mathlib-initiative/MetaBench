module

import MetaBench

#guard_msgs (drop info) in
#benchmark in
example : (2 : Nat) ^ 10 = 1024 := by decide

#guard_msgs (drop info) in
#benchmark "term proof" in
example (p q : Prop) (hp : p) (hq : q) : p ∧ q := ⟨hp, hq⟩

#guard_msgs (drop info) in
#benchmark in
theorem foo (x y : Nat) (h : x < y) : x + 1 <= y := by omega

/-- info: foo (x y : Nat) (h : x < y) : x + 1 ≤ y -/
#guard_msgs in #check foo

/-- error: Unknown identifier `rfll` -/
#guard_msgs in
#benchmark in theorem typo (a : Nat) : a = a := rfll

universe w
#guard_msgs (drop info) in
#benchmark in theorem univCmd (α : Sort w) (a : α) : a = a := rfl

/-- info: univCmd.{w} (α : Sort w) (a : α) : a = a -/
#guard_msgs in #check univCmd

namespace Nested
#guard_msgs (drop info) in
#benchmark in theorem inNamespace : True := trivial
end Nested

/-- info: Nested.inNamespace : True -/
#guard_msgs in #check Nested.inNamespace

/-- error: #benchmark supports `theorem` and `example` only -/
#guard_msgs in
#benchmark in def d : Nat := 1

/-- error: #benchmark: the proof must be a plain `:= proof` -/
#guard_msgs in
#benchmark in theorem eqns : Nat → Nat | n => n

/-- error: unsolved goals: [⊢ True] -/
#guard_msgs in
#benchmark in theorem bar : True := by skip

/-- error: benchmark proof contains sorry -/
#guard_msgs in
#benchmark in theorem bar : True := by sorry

-- `maxHeartbeats` counts from the start of a command; `#benchmark` restarts it per iteration
/--
error: (deterministic) timeout at `isDefEq`, maximum number of heartbeats (100) has been reached

Note: Use `set_option maxHeartbeats <num>` to set the limit.

Hint: Additional diagnostic information may be available using the `set_option diagnostics true` command.
-/
#guard_msgs in
set_option maxHeartbeats 100 in
run_cmd do
  for _ in [0:6] do
    Lean.Elab.Command.elabCommand (← `(example : (2 : Nat) ^ 10 = 1024 := by decide))

#guard_msgs (drop info) in
set_option maxHeartbeats 100 in
#benchmark in example : (2 : Nat) ^ 10 = 1024 := by decide

/-- info: depth: dnf: maximum recursion depth has been reached -/
#guard_msgs in
set_option maxRecDepth 40 in
#benchmark "depth" in example : (List.range 120).all (fun i => i * i % 7 < 7) = true := by decide
