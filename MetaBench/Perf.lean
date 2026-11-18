module

/-!
# CPU Instruction counting

A `Perf.InstrCounter` counts the CPU instructions on a thread.

* On Linux it is a hardware counter from `perf_event_open`. It records only user-space CPU instructions.
* On macOS it is the kernel's count for the current thread using `thread_selfcounts`. The count includes the
  instructions the kernel runs on the thread's behalf.

Native implementations are in `native/perf_linux.c` and `native/perf_macos.c`.
-/

namespace MetaBench.Perf

/-- Open a counter for the calling thread. Returns its descriptor, or `-errno`. -/
@[extern "metabench_instr_count_open"]
opaque openRaw : BaseIO Int32

/-- The count of the counter with descriptor `fd`, or `-errno`. -/
@[extern "metabench_instr_count_read"]
opaque readRaw (fd : Int32) : BaseIO Int64

/-- Close the counter with descriptor `fd`. Returns `0` or `-errno`. -/
@[extern "metabench_instr_count_close"]
opaque closeRaw (fd : Int32) : BaseIO Int32

/-- macOS native errnos. -/
inductive MacOSErrno where
  | ENOTSUP

def MacOSErrno.ofInt32? : Int32 → Option MacOSErrno
  | 45 => some .ENOTSUP
  | _ => none

instance : ToString MacOSErrno where
  toString
    | .ENOTSUP => "ENOTSUP"

/-- Linux native errnos. -/
inductive LinuxErrno where
  | EPERM | ENOENT | EIO | EACCES | ENODEV | ENOSYS | EOPNOTSUPP

def LinuxErrno.ofInt32? : Int32 → Option LinuxErrno
  | 1 => some .EPERM
  | 2 => some .ENOENT
  | 5 => some .EIO
  | 13 => some .EACCES
  | 19 => some .ENODEV
  | 38 => some .ENOSYS
  | 95 => some .EOPNOTSUPP
  | _ => none

instance : ToString LinuxErrno where
  toString
    | .EPERM => "EPERM"
    | .ENOENT => "ENOENT"
    | .EIO => "EIO"
    | .EACCES => "EACCES"
    | .ENODEV => "ENODEV"
    | .ENOSYS => "ENOSYS"
    | .EOPNOTSUPP => "EOPNOTSUPP"

def MacOSErrno.explain : MacOSErrno → String
  | .ENOTSUP => "this machine does not record an instruction count"

def LinuxErrno.explain : LinuxErrno → String
  | .EPERM | .EACCES =>
    "the kernel refused perf_event_open: it needs `kernel.perf_event_paranoid` at 2 or lower"
  | .ENOENT | .ENODEV | .EOPNOTSUPP => "this machine exposes no hardware instruction counter"
  | .ENOSYS => "the kernel has no perf_event_open"
  | .EIO => "perf_event_open or the read of its counter failed"

def describe {ε : Type} [ToString ε] (errno : Int32) (e? : Option ε) (explain : ε → String)
    (unnamed : String) : String :=
  match e? with
  | some e => s!"{explain e} ({e}, errno {errno})"
  | none => s!"{unnamed} (errno {errno})"

def explain (errno : Int32) : String :=
  if System.Platform.isOSX then
    describe errno (MacOSErrno.ofInt32? errno) MacOSErrno.explain "thread_selfcounts failed"
  else
    describe errno (LinuxErrno.ofInt32? errno) LinuxErrno.explain
      "perf_event_open or the read of its counter failed"

/-- A counter of CPU instructions. -/
public structure InstrCounter where
  private mk ::
  /-- The descriptor `perf_event_open` returned on Linux. Unused on macOS. -/
  fd : Int32

/-- Open an instruction counter for the calling thread. -/
def InstrCounter.open : IO InstrCounter := do
  unless System.Platform.isLinux || System.Platform.isOSX do
    throw <| .userError "bench.instructions: instructions can only be counted on Linux and macOS"
  let fd ← openRaw
  if fd < 0 then
    throw <| .userError s!"bench.instructions: {explain (-fd)}"
  return { fd }

def InstrCounter.close (instrCounter : InstrCounter) : IO Unit :=
  discard <| closeRaw instrCounter.fd

/-- The instruction counter's running total. It must be read on the thread that opened the counter. -/
public def InstrCounter.read (instrCounter : InstrCounter) : IO Nat := do
  let count ← readRaw instrCounter.fd
  if count < 0 then
    throw <| .userError s!"bench.instructions: {explain (-count).toInt32}"
  return count.toNatClampNeg

/-- Run `act` with a CPU instruction counter opened for the calling thread, and close it when `act` is done. -/
public def withInstrCounter {m : Type → Type} {α : Type} [Monad m] [MonadLiftT IO m] [MonadFinally m]
    (act : InstrCounter → m α) : m α := do
  let instrCounter ← InstrCounter.open
  try act instrCounter finally instrCounter.close

end MetaBench.Perf
