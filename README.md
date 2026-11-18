# MetaBench

A library for benchmarking Lean metaprograms.

The `#benchmark` command is used with a `theorem` or `example` and measures wall-clock time and
heartbeats for elaborating the goal, constructing the proof, and kernel-checking.

## Quickstart

```lean
import MetaBench

#benchmark in
theorem foo (x y : Nat) (h : x < y) : x + 1 <= y := by omega
```

The following is shown in the infoview.

```
phase    kHB     min…max   ms   min…max
goal    9.25  9.24…13.36 0.20 0.20…0.37
proof  14.54 14.52…16.01 0.36 0.32…0.46
kernel  0.57   0.55…0.57 0.04 0.03…0.05
total  24.36 24.33…29.92 0.59 0.54…0.87
proof term: 53 nodes, kernel 827 ns/node
```

With `set_option bench.proofHeads n` the report also lists the `n` most frequent head constants of the proof term.
With `set_option bench.kernelUnfolds n` it lists the `n` declarations the kernel unfolded most often while checking it.

``` lean
import MetaBench

set_option bench.proofHeads 5 in
#benchmark in
theorem foo (a b c : Nat) (h₁ : a = b) (h₂ : b = c) : a + 0 = c := by
  rw [Nat.add_zero, h₁, h₂]
```

The following output is show in the infoview:

```
foo:
phase    kHB     min…max   ms   min…max
goal   13.65 13.64…13.66 0.30 0.30…0.50
proof   7.09   7.08…7.10 0.17 0.17…0.29
kernel  0.92   0.92…0.92 0.06 0.05…0.08
total  21.66 21.64…21.67 0.53 0.52…0.87
proof term: 91 nodes, kernel 676 ns/node

proof heads count
Eq              9
Eq.mpr          3
congrArg        3
id              3
Eq.refl         1
```

## Example Suites

[`example/`](example/) contains benchmark suites for the `eval_det` and `eval_rank` tactics.

Run them against a **built** Mathlib checkout using the
[`example/bench-run.sh`](example/bench-run.sh) script.

```
METABENCH=. example/bench-run.sh <mathlib-checkout> example/Suites/Det.lean
```

## Defining your own suites

Use [`example/`](example/) as a template and copy it to a new directory outside of this repository.
When using the `bench-run.sh` script, the `METABENCH` environment variable should point to a
checkout of this repo.

## JSONL output

Set the `bench.out` option to append one JSON object per benchmark to a file, one object per line.
The `bench.tag` option records a free-form tag with each object, such as the git revision under test.

```
METABENCH=. example/bench-run.sh <mathlib-checkout> example/Suites/Det.lean -Dbench.out=results.jsonl -Dbench.tag=$(git -C <mathlib-checkout> rev-parse --short HEAD)
```

Each object has the fields:

- `label`: the benchmark's name.
- `run`: the start time of the process in UTC, shared by every benchmark of one run, so runs appended
  to the same file can be told apart.
- `tag`: the `bench.tag` option.
- `lean`: the Lean version.
- `file`, `line`: the location of the `#benchmark` command.
- `options`: the options in force, as an object.
- `proofNodes`, `typeNodes`: the number of distinct subterms of the proof and of the statement.
- `proofHeads`: the number of distinct subterms of the proof headed by each constant.
- `kernelUnfolds`: how many times the kernel unfolded each declaration while checking the proof.
- `warmup`: the samples of the warmup, per phase.
- `iters`: the samples of every measured iteration, per phase.

A sample is `{"heartbeats": n, "nanos": n}` and the phases are `goal`, `proof` and `kernel`. When
[instructions are counted](#counting-instructions) a sample also contains the `"instructions"` field. 

## Counting CPU instructions

Pass the `-Dbench.instructions=true` flag to count the CPU instructions run on each phase. Unlike
heartbeats the count sees arithmetic on large numbers, and it varies less than the clock.

```
METABENCH=. example/bench-run.sh <mathlib-checkout> example/Suites/Det.lean -Dbench.instructions=true
```

The report has a `Minstr` column in units of millions of CPU instructions.

This feature is provided as a native library in the `perfDynlib` target that lake builds with the
system's C compiler. The path to the built shared library (which can be obtained using
`lake query -q perfDynlib`) must be passed to lean using its `--load-dynlib` flag whenever the
`-Dbench.instructions=true` flag is used.

If a system C compiler is available then `example/bench-run.sh` automatically builds the `perfDynlib` target and passes `--load-dynlib`.

The Linux and macOS implementations count instructions differently, so the numbers are not comparable with each other:

- **Linux** ([`native/perf_linux.c`](native/perf_linux.c)) reads a hardware counter with
  `perf_event_open`. Some CI and container hosts do not expose this counter and this feature will
  not work in this case. `kernel.perf_event_paranoid` must be 2 or lower.
- **macOS** ([`native/perf_macos.c`](native/perf_macos.c)) reads the kernel's count for the thread
  with `thread_selfcounts`.
