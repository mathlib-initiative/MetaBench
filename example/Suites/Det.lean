/-
Run in the root of the repo with:

  METABENCH=. example/bench-run.sh <mathlib-checkout> example/Suites/Det.lean
-/
import Mathlib.Tactic.NormDet
import MetaBench

#benchmark "eval_det/int/2" in example :
    (!![-8, -2;
        -1,  3] : Matrix (Fin 2) (Fin 2) ℤ).det = -26 := by
  eval_det

#benchmark "eval_det/int/3" in example :
    (!![-2, -4, -3;
         3,  3,  5;
         4,  6, -8] : Matrix (Fin 3) (Fin 3) ℤ).det = -86 := by
  eval_det

#benchmark "eval_det/int/4" in example :
    (!![-2,  7, -9,  1;
        -6, -4, -3, -8;
        -3, -2,  1, -2;
         9,  7,  6,  8] : Matrix (Fin 4) (Fin 4) ℤ).det = -801 := by
  eval_det

#benchmark "eval_det/int/5" in example :
    (!![-5,  5, -2, -1, -2;
        -7,  5,  8, -1,  3;
         3,  0, -8,  4, -5;
        -3, -3, -5, -9,  6;
         6, -2,  5, -6, -9] : Matrix (Fin 5) (Fin 5) ℤ).det = -2688 := by
  eval_det

#benchmark "eval_det/int/6" in example :
    (!![ 8, -9, -4,  6,  5,  0;
         9, -1,  5, -4, -4,  6;
        -6, -9, -2, -5, -3, -6;
         9, -6, -8,  9,  3,  8;
         3,  0,  5,  6, -2, -6;
         4, -5,  5,  9,  5, -1] : Matrix (Fin 6) (Fin 6) ℤ).det = 1041909 := by
  eval_det

#benchmark "eval_det/int/cartan8" in example :
    (!![ 2,  0, -1,  0,  0,  0,  0,  0;
         0,  2,  0, -1,  0,  0,  0,  0;
        -1,  0,  2, -1,  0,  0,  0,  0;
         0, -1, -1,  2, -1,  0,  0,  0;
         0,  0,  0, -1,  2, -1,  0,  0;
         0,  0,  0,  0, -1,  2, -1,  0;
         0,  0,  0,  0,  0, -1,  2, -1;
         0,  0,  0,  0,  0,  0, -1,  2] : Matrix (Fin 8) (Fin 8) ℤ).det = 1 := by
  eval_det

#benchmark "eval_det/int/8" in example :
    (!![ 7,  5,  1, -7, -6, -8, -5,  9;
        -6,  9,  2, -9,  8,  1, -1, -2;
         6, -5,  8, -8, -3, -5, -6, -2;
         3,  2, -6, -6, -5, -2,  2, -2;
        -2, -6,  5,  5,  0,  1, -5,  5;
         2,  5,  9,  1,  4,  2,  9,  2;
         4,  2, -8,  8,  7, -2,  6, -5;
         0, -8, -2,  6, -1,  1,  5,  6] : Matrix (Fin 8) (Fin 8) ℤ).det = -13461368 := by
  eval_det

#benchmark "eval_det/int/10" in example :
    (!![-2,  8, -7,  4,  4,  4, -4, -5,  4, -3;
        -6,  7,  7,  2, -1,  9, -5,  3,  6,  2;
         7, -7, -9,  7,  7,  8,  0, -5, -5,  7;
        -4, -9, -3,  4, -6, -9, -9, -7,  8, -8;
         9,  9, -8,  0, -3, -2, -7, -2,  0,  9;
         0, -2,  7, -3,  1, -5,  1, -7,  6,  6;
         3, -8,  2, -4, -7, -2,  5, -1, -9, -6;
        -8,  3,  7, -6,  1, -3, -2, -8, -6,  6;
         5,  2, -8,  0, -6,  7, -9, -4, -7,  7;
         8,  9, -9,  5, -2, -9, -8, -2, -3, -1] : Matrix (Fin 10) (Fin 10) ℤ).det = 13336170446 := by
  eval_det

#benchmark "eval_det/int/12" in example :
    (!![ 1, -4, -5,  3, -3, -9,  2, -1,  4,  8,  9, -3;
        -5,  5,  4, -9,  3,  5, -6,  6, -2,  3,  6,  2;
        -4, -3,  3,  8, -5,  6,  8,  0, -2, -6, -4, -9;
        -1, -7,  7, -8, -2,  7, -4,  2, -3, -2, -8, -4;
         7, -2,  7,  7,  8,  1,  8,  7,  8,  3, -6,  2;
         7, -5,  2, -8, -4, -9, -3, -2, -5, -2, -8, -6;
        -8, -1, -1,  8,  7,  1, -9,  7,  3, -7, -6,  9;
         3,  0,  1,  3,  1, -5,  0,  6, -4,  0, -3,  9;
        -4,  7,  0,  5, -2,  3, -8,  5, -4, -4,  2,  2;
        -5,  1, -5,  6, -4, -4,  9,  4,  6,  5,  0,  1;
         2,  4,  9, -3,  1, -9, -9, -4, -6, -6,  8,  0;
         1, -7, -7,  7, -5,  9, -1, -1,  4,  6, -2,  7] : Matrix (Fin 12) (Fin 12) ℤ).det = 351393385384 := by
  eval_det

#benchmark "eval_det/rat/3" in example :
    (!![4/5,   -8, 5;
        4/3, -3/2, 0;
          3,    2, 8] : Matrix (Fin 3) (Fin 3) ℚ).det = _ := by
  eval_det
  rfl

#benchmark "eval_det/rat/4" in example :
    (!![  -1,    2, 3/2, -1/4;
        -7/2,    6,  -6,    6;
           3, -3/4,   9,  5/2;
          -1,   -4, 5/4, -3/4] : Matrix (Fin 4) (Fin 4) ℚ).det = _ := by
  eval_det
  rfl

#benchmark "eval_det/sym/2" in example (R : Type*) [CommRing R] (a b c d : R) :
    (!![a, b;
        c, d]).det = a * d - b * c := by
  eval_det
  ring1

#benchmark "eval_det/sym/4" in example (R : Type*) [CommRing R] (a b c d e f g h i j k l m n o p : R) :
    (!![a, b, c, d;
        e, f, g, h;
        i, j, k, l;
        m, n, o, p] : Matrix (Fin 4) (Fin 4) R).det =
      a * f * k * p - a * f * l * o - a * g * j * p + a * g * l * n + a * h *
        j * o - a * h * k * n - b * e * k * p + b * e * l * o + b * g * i * p
        - b * g * l * m - b * h * i * o + b * h * k * m + c * e * j * p - c *
        e * l * n - c * f * i * p + c * f * l * m + c * h * i * n - c * h * j
        * m - d * e * j * o + d * e * k * n + d * f * i * o - d * f * k * m -
        d * g * i * n + d * g * j * m := by
  eval_det
  ring1

#benchmark "eval_det/sym/5" in example (R : Type*) [CommRing R] (x00 x01 x02 x03 x04 x10 x11 x12 x13 x14 x20 x21 x22 x23 x24 x30 x31 x32 x33 x34 x40 x41 x42 x43 x44 : R) :
    (!![x00, x01, x02, x03, x04;
        x10, x11, x12, x13, x14;
        x20, x21, x22, x23, x24;
        x30, x31, x32, x33, x34;
        x40, x41, x42, x43, x44] : Matrix (Fin 5) (Fin 5) R).det =
      x00 * x11 * x22 * x33 * x44 - x00 * x11 * x22 * x34 * x43 - x00 * x11 * x23 * x32 *
        x44 + x00 * x11 * x23 * x34 * x42 + x00 * x11 * x24 * x32 * x43 - x00 * x11 * x24
        * x33 * x42 - x00 * x12 * x21 * x33 * x44 + x00 * x12 * x21 * x34 * x43 + x00 *
        x12 * x23 * x31 * x44 - x00 * x12 * x23 * x34 * x41 - x00 * x12 * x24 * x31 * x43
        + x00 * x12 * x24 * x33 * x41 + x00 * x13 * x21 * x32 * x44 - x00 * x13 * x21 *
        x34 * x42 - x00 * x13 * x22 * x31 * x44 + x00 * x13 * x22 * x34 * x41 + x00 * x13
        * x24 * x31 * x42 - x00 * x13 * x24 * x32 * x41 - x00 * x14 * x21 * x32 * x43 +
        x00 * x14 * x21 * x33 * x42 + x00 * x14 * x22 * x31 * x43 - x00 * x14 * x22 * x33
        * x41 - x00 * x14 * x23 * x31 * x42 + x00 * x14 * x23 * x32 * x41 - x01 * x10 *
        x22 * x33 * x44 + x01 * x10 * x22 * x34 * x43 + x01 * x10 * x23 * x32 * x44 - x01
        * x10 * x23 * x34 * x42 - x01 * x10 * x24 * x32 * x43 + x01 * x10 * x24 * x33 *
        x42 + x01 * x12 * x20 * x33 * x44 - x01 * x12 * x20 * x34 * x43 - x01 * x12 * x23
        * x30 * x44 + x01 * x12 * x23 * x34 * x40 + x01 * x12 * x24 * x30 * x43 - x01 *
        x12 * x24 * x33 * x40 - x01 * x13 * x20 * x32 * x44 + x01 * x13 * x20 * x34 * x42
        + x01 * x13 * x22 * x30 * x44 - x01 * x13 * x22 * x34 * x40 - x01 * x13 * x24 *
        x30 * x42 + x01 * x13 * x24 * x32 * x40 + x01 * x14 * x20 * x32 * x43 - x01 * x14
        * x20 * x33 * x42 - x01 * x14 * x22 * x30 * x43 + x01 * x14 * x22 * x33 * x40 +
        x01 * x14 * x23 * x30 * x42 - x01 * x14 * x23 * x32 * x40 + x02 * x10 * x21 * x33
        * x44 - x02 * x10 * x21 * x34 * x43 - x02 * x10 * x23 * x31 * x44 + x02 * x10 *
        x23 * x34 * x41 + x02 * x10 * x24 * x31 * x43 - x02 * x10 * x24 * x33 * x41 - x02
        * x11 * x20 * x33 * x44 + x02 * x11 * x20 * x34 * x43 + x02 * x11 * x23 * x30 *
        x44 - x02 * x11 * x23 * x34 * x40 - x02 * x11 * x24 * x30 * x43 + x02 * x11 * x24
        * x33 * x40 + x02 * x13 * x20 * x31 * x44 - x02 * x13 * x20 * x34 * x41 - x02 *
        x13 * x21 * x30 * x44 + x02 * x13 * x21 * x34 * x40 + x02 * x13 * x24 * x30 * x41
        - x02 * x13 * x24 * x31 * x40 - x02 * x14 * x20 * x31 * x43 + x02 * x14 * x20 *
        x33 * x41 + x02 * x14 * x21 * x30 * x43 - x02 * x14 * x21 * x33 * x40 - x02 * x14
        * x23 * x30 * x41 + x02 * x14 * x23 * x31 * x40 - x03 * x10 * x21 * x32 * x44 +
        x03 * x10 * x21 * x34 * x42 + x03 * x10 * x22 * x31 * x44 - x03 * x10 * x22 * x34
        * x41 - x03 * x10 * x24 * x31 * x42 + x03 * x10 * x24 * x32 * x41 + x03 * x11 *
        x20 * x32 * x44 - x03 * x11 * x20 * x34 * x42 - x03 * x11 * x22 * x30 * x44 + x03
        * x11 * x22 * x34 * x40 + x03 * x11 * x24 * x30 * x42 - x03 * x11 * x24 * x32 *
        x40 - x03 * x12 * x20 * x31 * x44 + x03 * x12 * x20 * x34 * x41 + x03 * x12 * x21
        * x30 * x44 - x03 * x12 * x21 * x34 * x40 - x03 * x12 * x24 * x30 * x41 + x03 *
        x12 * x24 * x31 * x40 + x03 * x14 * x20 * x31 * x42 - x03 * x14 * x20 * x32 * x41
        - x03 * x14 * x21 * x30 * x42 + x03 * x14 * x21 * x32 * x40 + x03 * x14 * x22 *
        x30 * x41 - x03 * x14 * x22 * x31 * x40 + x04 * x10 * x21 * x32 * x43 - x04 * x10
        * x21 * x33 * x42 - x04 * x10 * x22 * x31 * x43 + x04 * x10 * x22 * x33 * x41 +
        x04 * x10 * x23 * x31 * x42 - x04 * x10 * x23 * x32 * x41 - x04 * x11 * x20 * x32
        * x43 + x04 * x11 * x20 * x33 * x42 + x04 * x11 * x22 * x30 * x43 - x04 * x11 *
        x22 * x33 * x40 - x04 * x11 * x23 * x30 * x42 + x04 * x11 * x23 * x32 * x40 + x04
        * x12 * x20 * x31 * x43 - x04 * x12 * x20 * x33 * x41 - x04 * x12 * x21 * x30 *
        x43 + x04 * x12 * x21 * x33 * x40 + x04 * x12 * x23 * x30 * x41 - x04 * x12 * x23
        * x31 * x40 - x04 * x13 * x20 * x31 * x42 + x04 * x13 * x20 * x32 * x41 + x04 *
        x13 * x21 * x30 * x42 - x04 * x13 * x21 * x32 * x40 - x04 * x13 * x22 * x30 * x41
        + x04 * x13 * x22 * x31 * x40 := by
  eval_det
  ring1

#benchmark "eval_det/sym/sylvester7" in example (R : Type*) [CommRing R] (a b c d e : R) :
    (!![a    , b    , c    , d    , e    , 0    , 0;
        0    , a    , b    , c    , d    , e    , 0;
        0    , 0    , a    , b    , c    , d    , e;
        4 * a, 3 * b, 2 * c, d    , 0    , 0    , 0;
        0    , 4 * a, 3 * b, 2 * c, d    , 0    , 0;
        0    , 0    , 4 * a, 3 * b, 2 * c, d    , 0;
        0    , 0    , 0    , 4 * a, 3 * b, 2 * c, d] : Matrix (Fin 7) (Fin 7) R).det =
      a * (256 * a ^ 3 * e ^ 3 - 192 * a ^ 2 * b * d * e ^ 2
        - 128 * a ^ 2 * c ^ 2 * e ^ 2 + 144 * a ^ 2 * c * d ^ 2 * e
        - 27 * a ^ 2 * d ^ 4 + 144 * a * b ^ 2 * c * e ^ 2
        - 6 * a * b ^ 2 * d ^ 2 * e - 80 * a * b * c ^ 2 * d * e
        + 18 * a * b * c * d ^ 3 + 16 * a * c ^ 4 * e
        - 4 * a * c ^ 3 * d ^ 2 - 27 * b ^ 4 * e ^ 2
        + 18 * b ^ 3 * c * d * e - 4 * b ^ 3 * d ^ 3
        - 4 * b ^ 2 * c ^ 3 * e + b ^ 2 * c ^ 2 * d ^ 2) := by
  eval_det
  ring1
