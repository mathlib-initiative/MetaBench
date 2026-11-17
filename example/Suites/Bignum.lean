/-
Run in the root of the repo with:

  METABENCH=. example/bench-run.sh <mathlib-checkout> example/Suites/Bignum.lean -Dbench.instructions=true
-/
import MetaBench

-- `decide` only evaluates `3 ^ n` for exponents up to this threshold, which is 256 by default.
set_option exponentiation.threshold 1000000

#benchmark "pow-mod/1000" in example : 3 ^ 1000 % 1000003 = 73216 := by decide
#benchmark "pow-mod/10000" in example : 3 ^ 10000 % 1000003 = 218751 := by decide
#benchmark "pow-mod/100000" in example : 3 ^ 100000 % 1000003 = 799099 := by decide
#benchmark "pow-mod/1000000" in example : 3 ^ 1000000 % 1000003 = 222223 := by decide

#benchmark "gcd/1000" in example : Nat.gcd (3 ^ 1000) (5 ^ 1000) = 1 := by decide
#benchmark "gcd/10000" in example : Nat.gcd (3 ^ 10000) (5 ^ 10000) = 1 := by decide
#benchmark "gcd/100000" in example : Nat.gcd (3 ^ 100000) (5 ^ 100000) = 1 := by decide
#benchmark "gcd/1000000" in example : Nat.gcd (3 ^ 1000000) (5 ^ 1000000) = 1 := by decide
