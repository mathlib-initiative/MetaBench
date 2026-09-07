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
/--
info: foo:
phase    kHB     min…max   ms   min…max
goal    9.42  9.40…13.53 0.25 0.21…0.39
proof  14.54 14.53…16.01 0.41 0.37…0.56
kernel  0.57   0.56…0.57 0.04 0.04…0.07
total  24.53 24.50…30.09 0.70 0.62…1.00
proof term: 58 nodes, kernel 766 ns/node
-/
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

