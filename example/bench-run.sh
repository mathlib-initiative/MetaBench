#!/usr/bin/env bash
# Run a benchmark suite against a built Mathlib checkout.
#
#   METABENCH=~/work/bench bench-run.sh <mathlib-dir> <suite.lean> [lean args]
#
set -euo pipefail
bench="$(cd "${METABENCH:?set METABENCH to the harness checkout}" && pwd)"
mathlib="${1:?usage: METABENCH=<harness> bench-run.sh <mathlib-dir> <suite.lean> [lean args]}"
suite="${2:?usage: METABENCH=<harness> bench-run.sh <mathlib-dir> <suite.lean> [lean args]}"
shift 2

if [ ! -f "$bench/lakefile.toml" ]; then
  echo "error: METABENCH=$bench is not the benchmark library checkout" >&2; exit 2
fi
if [ ! -f "$mathlib/.lake/build/lib/lean/Mathlib.olean" ]; then
  echo "error: $mathlib is not a built Mathlib checkout" >&2; exit 2
fi
if ! diff -q "$bench/lean-toolchain" "$mathlib/lean-toolchain" >/dev/null; then
  echo "error: toolchain mismatch: harness $(cat "$bench/lean-toolchain"), checkout $(cat "$mathlib/lean-toolchain")" >&2
  exit 2
fi
(cd "$bench" && lake build MetaBench >/dev/null)
exec lake +"$(cat "$mathlib/lean-toolchain")" --dir "$mathlib" env \
  sh -c 'LEAN_PATH="$LEAN_PATH:$0" exec lean -DElab.async=false "$@"' \
  "$bench/.lake/build/lib/lean" "$suite" "$@"
