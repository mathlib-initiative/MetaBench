module

public import Std.Time.Duration
import Lean

open Lean Elab Std.Time

namespace MetaBench

public section

/-- A `Sample` is a pair of a monotonic clock value (in nanoseconds) and the heartbeat count at that
moment. -/
structure Sample where
  nanos : Nat
  heartbeats : Nat

@[inline] def Sample.now : BaseIO Sample := do
  return { nanos := ← IO.monoNanosNow, heartbeats := ← IO.getNumHeartbeats }

/-- The interval from `earlier` to `later`. -/
def Sample.sub (later earlier : Sample) : Sample :=
  { nanos := later.nanos - earlier.nanos, heartbeats := later.heartbeats - earlier.heartbeats }

def Sample.add (s1 s2 : Sample) : Sample :=
  { nanos := s1.nanos + s2.nanos, heartbeats := s1.heartbeats + s2.heartbeats }

/-- Elapsed time as a `Duration`, for display. -/
def Sample.toDuration (s : Sample) : Duration := .ofNanoseconds (.ofNat s.nanos)

inductive Phase where
  | goal
  | proof
  | kernel

def Phase.name : Phase → String
  | .goal => "goal"
  | .proof => "proof"
  | .kernel => "kernel"

instance : ToString Phase := ⟨Phase.name⟩

def Phase.all : Array Phase := #[.goal, .proof, .kernel]

theorem Phase.mem_all (p : Phase) : p ∈ Phase.all :=
  by cases p <;> simp [Phase.all]

abbrev PhaseSamples := Phase → Sample

def PhaseSamples.total (ps : PhaseSamples) : Sample :=
  Phase.all.foldl (fun acc p => acc.add (ps p) ) ⟨0, 0⟩

/-- Format a float with `prec` digits after the decimal point. -/
public def fmtFloat (x : Float) (precision : Nat := 2) : String :=
  let neg := x < 0
  let x := x.abs
  let m := 10 ^ precision
  let scaled := (x * m.toFloat).round
  if scaled >= UInt64.size.toFloat then toString x
  else
    let r := scaled.toUInt64.toNat
    let ip := r / m
    let fp := r % m
    let fps := String.ofList ((toString fp).toList.leftpad precision '0')
    (if neg then "-" else "") ++ toString ip ++ (if precision == 0 then "" else "." ++ fps)

def PhaseSamples.render (ps : PhaseSamples) : String :=
  let row (name : String) (s : Sample) :=
    #[name, fmtFloat (s.heartbeats.toFloat / 1000.0), "kHB",
      fmtFloat (s.nanos.toFloat / 1_000_000), "ms"]
  let rows := Phase.all.map (fun p => row (p.name) (ps p)) |>.push (row "total" ps.total)
  Elab.WF.GuessLex.formatTable rows

end

end MetaBench
