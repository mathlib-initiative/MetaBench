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
foo:
phase    kHB     min…max   ms   min…max
goal    9.25  9.24…13.36 0.20 0.19…0.40
proof  14.54 14.53…16.01 0.33 0.32…0.46
kernel  0.56   0.55…0.56 0.04 0.03…0.04
total  24.36 24.33…29.92 0.56 0.54…0.91
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

