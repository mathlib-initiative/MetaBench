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
- `constants`: the number of distinct subterms of the proof headed by each constant.
- `warmup`: the samples of the warmup, per phase.
- `iters`: the samples of every measured iteration, per phase.

A sample is `{"heartbeats": n, "nanos": n}` and the phases are `goal`, `proof` and `kernel`. The
file loads into pandas with `pd.read_json(path, lines=True)`. On the Lean side the same record is
`MetaBench.Report`, with `ToJson` and `FromJson` instances.
