module

import MetaBench

/-! An example showing that large kernel work can be hidden from the profiler but observed by clock
time measurements -/

set_option trace.profiler.useHeartbeats true
set_option trace.profiler.threshold 5000
set_option exponentiation.threshold 3000000
set_option Elab.async false

abbrev PowSmall : Prop := 3 ^ 300 % 1000003 = 987367
abbrev PowBig : Prop := 3 ^ 3000000 % 1000003 = 545955

set_option trace.profiler true in
theorem pow_small : PowSmall := by decide
#benchmark "pow/300" in example : PowSmall := by decide

set_option trace.profiler true in
theorem pow_big : PowBig := by decide
#benchmark "pow/3000000" in example : PowBig := by decide
