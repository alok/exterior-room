/-
Checked Single domain facts and cancellation for the actual coefficient fold.
Chosen inverse laws are explicit; Rat discharges them from genuine nonzero division.
-/
import Grassmann.Dynamic.SingleInt
import Grassmann.Dynamic.PowerLaws

namespace Grassmann

open DirectSum AbstractTensors

namespace TA

variable {α : Type} [Coeff α]

/-- A coefficient commuting with y commutes with its actual left-fold power.
Only associative multiplication and the two identities are required. -/
theorem cpow_commute (assoc : ∀ a b c : α, (a*b)*c = a*(b*c))
    (left_id : ∀ a : α, Coeff.one*a = a) (right_id : ∀ a : α, a*Coeff.one = a)
    (x y : α) (comm : x*y = y*x) (n : Nat) : x * cpow y n = cpow y n * x := by
  induction n with
  | zero => simp only [cpow_zero, left_id, right_id]
  | succ n ih =>
    rw [cpow_succ, ← assoc, ih, assoc, comm, ← assoc]

/-- Powers of a chosen two-sided inverse pair cancel in the actual cpow implementation.
This is a monoid-with-inverse-pair result, with no Field, addition or commutativity. -/
theorem cpow_inverse_cancel (assoc : ∀ a b c : α, (a*b)*c = a*(b*c))
    (left_id : ∀ a : α, Coeff.one*a = a) (right_id : ∀ a : α, a*Coeff.one = a)
    (x y : α) (xy : x*y = Coeff.one) (yx : y*x = Coeff.one) (n : Nat) :
    cpow x n * cpow y n = Coeff.one := by
  induction n with
  | zero => simp only [cpow_zero, left_id]
  | succ n ih =>
    rw [cpow_succ, cpow_succ, ← assoc, assoc (cpow x n) x (cpow y n),
      cpow_commute assoc left_id right_id x y (xy.trans yx.symm) n,
      ← assoc, assoc (cpow x n * cpow y n) x y, xy, right_id, ih]

/-- Genuine Rat nonzero division supplies both inverse-pair premises for cpow. -/
theorem rat_cpow_inverse_cancel (x : Rat) (hx : x ≠ 0) (n : Nat) :
    cpow x n * cpow (1/x) n = 1 := by
  have xy : x * (1/x) = 1 := by
    simpa only [Rat.div_def, Rat.one_mul] using Rat.mul_inv_cancel x hx
  have yx : (1/x) * x = 1 := by
    simpa only [Rat.div_def, Rat.one_mul] using Rat.inv_mul_cancel x hx
  exact cpow_inverse_cancel Rat.mul_assoc Rat.one_mul Rat.mul_one x (1/x) xy yx n

end TA

namespace Single

variable {V : TensorBundle} {G : Nat} {α : Type} [Coeff α] [Kernels V] [Div α]

/-- Nonnegative checked powers route to the existing natural-power API, without a guard. -/
theorem powInt?_nonneg (s : Single V G α) (i : Int) (hi : i ≥ 0) :
    s.powInt? i = some (s.powNat i.toNat) := by simp only [powInt?, hi, ↓reduceIte]

/-- A negative exponent rejects a computationally zero inverse denominator. -/
theorem powInt?_reject (s : Single V G α) (i : Int) (hi : i < 0)
    (hz : Coeff.isZero s.invDenominator = true) : s.powInt? i = none := by
  simp only [powInt?, show ¬i ≥ 0 by omega, hz, ↓reduceIte]

/-- A negative exponent with a passing denominator guard uses the actual inverse formula. -/
theorem powInt?_negative (s : Single V G α) (i : Int) (hi : i < 0)
    (hz : Coeff.isZero s.invDenominator = false) :
    s.powInt? i = some (TA.powNat (TA.invTerm s.bits s.val) i.natAbs) := by
  simp only [powInt?, show ¬i ≥ 0 by omega, hz, Bool.false_eq_true, ↓reduceIte]

end Single

namespace Single

variable {V : TensorBundle} {G : Nat} [Kernels V]

/-- For Rat the finite-domain rejection guard exactly detects the actual denominator zero.
This supplies a domain fact, not geometric invertibility for arbitrary raw masks. -/
theorem powInt?_rat_none_iff (s : Single V G Rat) (i : Int) (hi : i < 0) :
    s.powInt? i = none ↔ s.invDenominator = 0 := by
  simp only [powInt?, show ¬i ≥ 0 by omega, ↓reduceIte]
  change (if s.invDenominator == 0 then none else
    some (TA.powNat (TA.invTerm s.bits s.val) i.natAbs)) = none ↔ _
  split <;> simp_all only [beq_iff_eq, Option.some_ne_none]

/-- Scalar checked negative powers refine through invTerm and genuine Rat division
to the actual coefficient fold, for arbitrary nonzero x and n (including n=0). -/
theorem powInt?_scalar_rat_coeff (sq : TA.bladeSq V 0 = 1)
    (basis_mul : TA.mul (.one : TA V Rat) .one = .one)
    (x : Rat) (hx : x ≠ 0) (n : Nat) :
    ((scalar (V := V) x).powInt? (-(n : Int))).map (fun t => t.coeff 0) =
      some (TA.cpow (1/x) n) := by
  cases n with
  | zero =>
    rw [powInt?_nonneg _ _ (by omega)]
    change some (((scalar (V := V) x).powNat 0).coeff 0) = some Coeff.one
    rw [powNat_zero]
    rfl
  | succ n =>
    have guard : Coeff.isZero (scalar (V := V) x).invDenominator = false := by
      change (x == 0) = false
      simp [hx]
    rw [powInt?_negative _ _ (by omega) guard]
    simp only [scalar, TA.invTerm, BEq.rfl, ↓reduceIte, Int.natAbs_neg,
      Int.natAbs_natCast, Option.map_some]
    change some (((scalar (V := V) (1/x)).powNat (n+1)).coeff 0) = _
    rw [powNat_scalar_coeff sq basis_mul Rat.one_mul]

/-- Actual typed scalar coefficients at n and checked -n cancel for arbitrary nonzero Rat x.
Only scalar metric/basis witnesses are added to the discharged Rat inverse-pair laws. -/
theorem powInt?_scalar_rat_cancel (sq : TA.bladeSq V 0 = 1)
    (basis_mul : TA.mul (.one : TA V Rat) .one = .one)
    (x : Rat) (hx : x ≠ 0) (n : Nat) :
    ((scalar (V := V) x).powInt? (-(n : Int))).map
      (fun t => ((scalar (V := V) x).powNat n).coeff 0 * t.coeff 0) = some 1 := by
  have h := powInt?_scalar_rat_coeff sq basis_mul x hx n
  have mapped := congrArg (Option.map (fun y =>
    ((scalar (V := V) x).powNat n).coeff 0 * y)) h
  simpa only [Option.map_map, Function.comp_def, Option.map_some,
    powNat_scalar_coeff sq basis_mul Rat.one_mul, TA.rat_cpow_inverse_cancel x hx] using mapped

end Single

end Grassmann
