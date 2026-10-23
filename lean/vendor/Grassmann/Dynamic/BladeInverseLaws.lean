/- Exact blade inverse refinements through actual term products and the checked API. -/
import Grassmann.Dynamic.IntegerPowerLaws

namespace Grassmann

open DirectSum AbstractTensors

namespace TA

/-- Proof-only bare/stored result forms at an arbitrary output mask. Bare coefficients
remain implicit; this witness supplies no Coeff identity or cast-coherence law. -/
inductive BladeTermResult (d : UInt64) : BladeResult → Rat → Prop where
  /-- A value-free blade at the output mask. -/
  | bare : BladeTermResult d (.blade d) 1
  /-- A stored coefficient at the output mask. -/
  | stored (q : Rat) : BladeTermResult d (.single q d) q

/-- Actual scaling of bare/stored blade results, preserving coefficient operation order
and raw Single representation even when the output mask or coefficient is zero. -/
theorem smul_ofBladeResult_term {V : TensorBundle} {α : Type} [Coeff α]
    {d : UInt64} {r : BladeResult} {q : Rat} (term : BladeTermResult d r q) (c : α) :
    smul c (ofBladeResult r : TA V α) =
      match (generalizing := false) r with
      | .blade _ => .single d c
      | _ => .single d (c * Coeff.ofRat q) := by
  cases term with
  | bare =>
    by_cases h : d = 0
    · subst d; rfl
    · simp only [ofBladeResult, ofBlade, h, beq_iff_eq, ↓reduceIte, smul]
  | stored q => rfl

/-- Refine actual stored-Single geometric multiplication through an actual basis-result
witness. This shares termProd/ofBladeResult/smul without adding algebraic laws to Coeff. -/
theorem mul_single_blade_term {V : TensorBundle} {α : Type} [Coeff α] [Kernels V]
    (A B : UInt64) {d : UInt64} {r : BladeResult} {q : Rat}
    (basis : V.apply₂ .mul A B = .ok r) (term : BladeTermResult d r q) (x y : α) :
    mul (.single A x : TA V α) (.single B y) =
      match (generalizing := false) r with
      | .blade _ => .single d (x*y)
      | _ => .single d ((x*y) * Coeff.ofRat q) := by
  change termProd .mul A x false B y false = _
  simp only [termProd, POp.bin, basis, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  exact smul_ofBladeResult_term term (x*y)

/-- Proof-only scalar blade-result forms: a bare scalar blade denotes 1, or a stored scalar q.
This witness preserves the raw result constructor; it does not normalize executable products. -/
inductive ScalarBladeResult : BladeResult → Rat → Prop where
  /-- The value-free bare scalar basis result. -/
  | bare : ScalarBladeResult (.blade 0) 1
  /-- A stored scalar coefficient and blade. -/
  | stored (q : Rat) : ScalarBladeResult (.single q 0) q

/-- Actual coefficient scaling keeps the distinction between bare and stored scalar results.
Coeff alone supplies neither ofRat-one coherence nor multiplication identity laws. -/
theorem smul_ofBladeResult_scalar {V : TensorBundle} {α : Type} [Coeff α]
    {r : BladeResult} {q : Rat} (scalar : ScalarBladeResult r q) (c : α) :
    smul c (ofBladeResult r : TA V α) =
      match (generalizing := false) r with
      | .blade _ => .single 0 c
      | _ => .single 0 (c * Coeff.ofRat q) := by
  cases scalar <;> rfl

/-- The actual Single product path refined by either proof-only scalar blade-result form. -/
theorem mul_single_scalar_square {V : TensorBundle} {α : Type} [Coeff α] [Kernels V]
    (b : UInt64) {r : BladeResult} {q : Rat}
    (square : V.apply₂ .mul b b = .ok r) (scalar : ScalarBladeResult r q) (x y : α) :
    mul (.single b x : TA V α) (.single b y) =
      match (generalizing := false) r with
      | .blade _ => .single 0 (x*y)
      | _ => .single 0 ((x*y) * Coeff.ofRat q) := by
  change termProd .mul b x false b y false = _
  simp only [termProd, POp.bin, square, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  exact smul_ofBladeResult_scalar scalar (x*y)

/-- A computational blade-square witness refines the actual Single product for any Coeff.
This assumes the value-free apply₂ result, not the desired inverse product. -/
theorem mul_single_square {V : TensorBundle} {α : Type} [Coeff α] [Kernels V]
    (b : UInt64) (q : Rat) (square : V.apply₂ .mul b b = .ok (.single q 0)) (x y : α) :
    mul (.single b x : TA V α) (.single b y) = .single 0 ((x*y) * Coeff.ofRat q) :=
  mul_single_scalar_square b square (.stored q) x y

/-- Genuine Rat identity/cast coherence gives a common coefficient formula for both raw forms. -/
theorem mul_single_scalar_square_rat {V : TensorBundle} [Kernels V]
    (b : UInt64) {r : BladeResult} {q : Rat}
    (square : V.apply₂ .mul b b = .ok r) (scalar : ScalarBladeResult r q) (x y : Rat) :
    mul (.single b x : TA V Rat) (.single b y) = .single 0 ((x*y)*q) := by
  rw [mul_single_scalar_square b square scalar]
  cases scalar with
  | bare => exact congrArg (single 0) (Rat.mul_one (x*y)).symm
  | stored q => rfl

/-- Raw constructor equality distinguishes stored scalar one from symbolic One for any Coeff. -/
theorem single_one_ne_one {V : TensorBundle} {α : Type} [Coeff α] :
    (.single 0 Coeff.one : TA V α) ≠ .one := by
  intro h
  cases h

/-- The two distinct unit representations nevertheless have the same actual dense value.
Only the shared Coeff.one and coefficient extraction are used, with no algebraic law class. -/
theorem toDense_single_one {V : TensorBundle} {α : Type} [Coeff α] :
    (.single 0 Coeff.one : TA V α).toDense = (.one : TA V α).toDense := by
  apply toDense_ext
  intro i
  simp only [dget_single, dget_one, valid_zero, Bool.and_true]

/-- Actual Rat division cancels the metric denominator under explicit nonzero/coherence facts.
Only genuine core multiplication/division laws are used, with no abstract Field assumption. -/
theorem rat_metric_inverse_cancel (q sign d x : Rat) (coherent : q*sign = d)
    (hd : d ≠ 0) (hx : x ≠ 0) : (x * (sign/(d*x))) * q = 1 := by
  have den : d*x ≠ 0 := by
    intro h
    rcases Rat.mul_eq_zero.mp h with h | h
    · exact hd h
    · exact hx h
  have numerator : (x*sign)*q = d*x := by
    rw [Rat.mul_assoc, Rat.mul_comm sign q, coherent, Rat.mul_comm x d]
  calc
    (x * (sign/(d*x))) * q = ((x*sign)*q) * (d*x)⁻¹ := by
      rw [Rat.div_def, ← Rat.mul_assoc x sign, Rat.mul_assoc (x*sign),
        Rat.mul_comm ((d*x)⁻¹) q, ← Rat.mul_assoc]
    _ = (d*x) * (d*x)⁻¹ := congrArg (· * (d*x)⁻¹) numerator
    _ = 1 := Rat.mul_inv_cancel _ den

/-- Both actual geometric products of a Rat term and invTerm are stored scalar Single 1.
Premises specify a nonzero mask/metric/coefficient, the blade-square computation,
and agreement of its scalar with the actual reversal sign and inverse metric. -/
theorem invTerm_rat_scalar_mul_pair {V : TensorBundle} [Kernels V] (b : UInt64) {r : BladeResult}
    (q x : Rat) (hb : b ≠ 0) (square : V.apply₂ .mul b b = .ok r)
    (scalar : ScalarBladeResult r q)
    (coherent : q * (if revSign b then (-1 : Rat) else 1) = abs2Inv V b)
    (hd : abs2Inv V b ≠ 0) (hx : x ≠ 0) :
    mul (.single b x : TA V Rat) (invTerm b x) = .single 0 1 ∧
      mul (invTerm b x : TA V Rat) (.single b x) = .single 0 1 := by
  let sign : Rat := if revSign b then -1 else 1
  have bits : (b == 0) = false := by simp [hb]
  have inverse : invTerm (V := V) b x = .single b (sign / (abs2Inv V b * x)) := by
    simp only [invTerm, bits, Bool.false_eq_true, ↓reduceIte]
    rfl
  rw [inverse, mul_single_scalar_square_rat b square scalar,
    mul_single_scalar_square_rat b square scalar]
  have forward := rat_metric_inverse_cancel q sign (abs2Inv V b) x coherent hd hx
  constructor
  · exact congrArg (single 0) forward
  · rw [Rat.mul_comm (sign / (abs2Inv V b * x)) x]
    exact congrArg (single 0) forward

/-- The original stored-square inverse API is a corollary of the shared scalar-result refinement. -/
theorem invTerm_rat_mul_pair {V : TensorBundle} [Kernels V] (b : UInt64) (q x : Rat)
    (hb : b ≠ 0) (square : V.apply₂ .mul b b = .ok (.single q 0))
    (coherent : q * (if revSign b then (-1 : Rat) else 1) = abs2Inv V b)
    (hd : abs2Inv V b ≠ 0) (hx : x ≠ 0) :
    mul (.single b x : TA V Rat) (invTerm b x) = .single 0 1 ∧
      mul (invTerm b x : TA V Rat) (.single b x) = .single 0 1 :=
  invTerm_rat_scalar_mul_pair b q x hb square (.stored q) coherent hd hx

end TA

namespace Single

/-- The non-null/nonzero Rat domain passes the actual guard and refines checked -1 to invTerm.
It makes no geometric invertibility claim without the additional blade witnesses. -/
theorem powInt?_neg_one_rat {V : TensorBundle} {G : Nat} [Kernels V]
    (s : Single V G Rat) (hb : s.bits ≠ 0) (hd : TA.abs2Inv V s.bits ≠ 0)
    (hx : s.val ≠ 0) : s ^? (-1) = some (TA.invTerm s.bits s.val) := by
  have den : TA.abs2Inv V s.bits * s.val ≠ 0 := by
    intro h
    rcases Rat.mul_eq_zero.mp h with h | h
    · exact hd h
    · exact hx h
  have guard : Coeff.isZero s.invDenominator = false := by
    have denominator : s.invDenominator = TA.abs2Inv V s.bits * s.val := by
      simp only [invDenominator, show (s.bits == 0) = false by simp [hb],
        Bool.false_eq_true, ↓reduceIte]
      rfl
    change (s.invDenominator == (0 : Rat)) = false
    rw [denominator]
    simp [den]
  rw [powInt?_negative s (-1) (by decide) guard]
  change some (TA.powNat _ 1) = _
  simp only [TA.invTerm, show (s.bits == 0) = false by simp [hb],
    Bool.false_eq_true, ↓reduceIte, TA.powNat, ↓reduceDIte]

/-- The checked Rat -1 result is a two-sided inverse in the actual TA term product path.
No global geometric group law or intrinsic raw Single mask/grade invariant is assumed. -/
theorem powInt?_rat_scalar_blade_mul_pair {V : TensorBundle} {G : Nat} [Kernels V]
    (s : Single V G Rat) {r : BladeResult} (q : Rat) (hb : s.bits ≠ 0)
    (square : V.apply₂ .mul s.bits s.bits = .ok r) (scalar : TA.ScalarBladeResult r q)
    (coherent : q * (if TA.revSign s.bits then (-1 : Rat) else 1) = TA.abs2Inv V s.bits)
    (hd : TA.abs2Inv V s.bits ≠ 0) (hx : s.val ≠ 0) :
    (s ^? (-1)).map (fun inv => (TA.mul (TA.ofSingle s) inv, TA.mul inv (TA.ofSingle s))) =
      some (.single 0 1, .single 0 1) := by
  rw [powInt?_neg_one_rat s hb hd hx, Option.map_some]
  have pair := TA.invTerm_rat_scalar_mul_pair s.bits q s.val hb square scalar coherent hd hx
  change some (TA.mul (.single s.bits s.val) _, TA.mul _ (.single s.bits s.val)) = _
  rw [pair.1, pair.2]

/-- The original stored-square checked inverse API retains its statement through the shared proof. -/
theorem powInt?_rat_blade_mul_pair {V : TensorBundle} {G : Nat} [Kernels V]
    (s : Single V G Rat) (q : Rat) (hb : s.bits ≠ 0)
    (square : V.apply₂ .mul s.bits s.bits = .ok (.single q 0))
    (coherent : q * (if TA.revSign s.bits then (-1 : Rat) else 1) = TA.abs2Inv V s.bits)
    (hd : TA.abs2Inv V s.bits ≠ 0) (hx : s.val ≠ 0) :
    (s ^? (-1)).map (fun inv => (TA.mul (TA.ofSingle s) inv, TA.mul inv (TA.ofSingle s))) =
      some (.single 0 1, .single 0 1) :=
  powInt?_rat_scalar_blade_mul_pair s q hb square (.stored q) coherent hd hx

end Single

end Grassmann
