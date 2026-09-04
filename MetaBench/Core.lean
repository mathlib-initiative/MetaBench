module

public import Std.Time.Duration

open Std.Time

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

/-- Elapsed time as a `Duration`, for display. -/
def Sample.toDuration (s : Sample) : Duration := .ofNanoseconds (.ofNat s.nanos)

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

end

end MetaBench
