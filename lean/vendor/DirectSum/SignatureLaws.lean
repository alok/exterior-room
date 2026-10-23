/- Canonical plain signature blade-product refinements through actual metric recursion. -/
import DirectSum.Ops

namespace DirectSum.TensorBundle

/-- Actual metricProduct.go preserves the two unit accumulators when every executable
metricAt factor is ±1. Induction is over its fuel, not a replacement mask model. -/
theorem metricProduct_go_unit (V : TensorBundle)
    (factors : ∀ i, V.metricAt i = 1 ∨ V.metricAt i = -1)
    (x : UInt64) (acc : Rat) (unit : acc = 1 ∨ acc = -1) (fuel : Nat) :
    metricProduct.go V x acc fuel = 1 ∨ metricProduct.go V x acc fuel = -1 := by
  induction fuel generalizing x acc with
  | zero => exact unit
  | succ fuel ih =>
    simp only [metricProduct.go]
    split
    · exact unit
    · apply ih
      rcases factors (Bits.ctz x + 1) with hf | hf <;>
        rcases unit with hu | hu <;> simp [hf, hu, Rat.mul_neg]

/-- The actual 64-fuel metric product is ±1 under pointwise unit metric factors.
No correctness assumption for ctz or bit-clear iteration is needed for magnitude. -/
theorem metricProduct_unit (V : TensorBundle)
    (factors : ∀ i, V.metricAt i = 1 ∨ V.metricAt i = -1) (b : UInt64) :
    V.metricProduct b = 1 ∨ V.metricProduct b = -1 :=
  metricProduct_go_unit V factors b 1 (Or.inl rfl) 64

/-- Canonical sig fixes no tangent slots; saturating shl keeps diffmask zero at n=64. -/
theorem sig_diffmask (n : Nat) (s : UInt64) : (sig n s).diffmask = 0 := by
  simp [diffmask, diffmaskV, diffmaskW, sig, isdyadic,
    Bits.lowMask, Bits.fullMask, Bits.shl]

/-- Actual canonical sig symmetricmask leaves both masks unchanged, with no Q/Z bits. -/
theorem sig_symmetricmask (n : Nat) (s A B : UInt64) :
    (sig n s).symmetricmask A B = (A,B,0,0) := by
  simp [symmetricmask, sig_diffmask]

/-- Actual signature metricAt is ±1 at every index, including out-of-range reads.
This is computational behavior, not a certificate that an arbitrary mask is valid. -/
theorem sig_metricAt_unit (n : Nat) (s : UInt64) (i : Nat) :
    (sig n s).metricAt i = 1 ∨ (sig n s).metricAt i = -1 := by
  simp only [metricAt, sig]
  split <;> simp

/-- Canonical sig metric product magnitude uses the actual recursive implementation. -/
theorem sig_metricProduct_unit (n : Nat) (s b : UInt64) :
    (sig n s).metricProduct b = 1 ∨ (sig n s).metricProduct b = -1 :=
  metricProduct_unit (sig n s) (sig_metricAt_unit n s) b

/-- Actual parity for canonical sig is parityjoin with its dimension-clamped sign bits. -/
theorem sig_parity (n : Nat) (s A B : UInt64) :
    (sig n s).parity A B = parityjoin (sig n s).sigBits A B := by
  simp [parity, sig_diffmask]

/-- Taking the actual metric product's absolute value leaves magnitude1; parity supplies
the combined sign independently. This proves no general coefficient arithmetic law. -/
theorem sig_parityinner (n : Nat) (s A B : UInt64) :
    (sig n s).parityinner A B =
      (if parityjoin (sig n s).sigBits A B then (-1 : Rat) else 1) := by
  have pos : ¬ (1 : Rat) < 0 := by decide +kernel
  have neg : (-1 : Rat) < 0 := by decide +kernel
  rcases sig_metricProduct_unit n s (A &&& B) with hp | hp <;>
    simp [parityinner, sig_symmetricmask, hp, sig_parity, pos, neg]

/-- Actual canonical sig overlap chooses stored Single, including positive sign1.
This internal computational equation does not certify raw mask validity or printing. -/
theorem sig_mul_overlap (n : Nat) (s A B : UInt64) (shared : A &&& B ≠ 0) :
    (sig n s).mul A B =
      .single (if parityjoin (sig n s).sigBits A B then -1 else 1) (A ^^^ B) := by
  have overlap : (A &&& B == 0) = false := by simp [shared]
  have diag : (sig n s).isdiag = true := rfl
  have tangent : (sig n s).istangent = false := rfl
  have nest (r : BladeResult) : (sig n s).nestTangent 0 r = r := rfl
  simp only [mul, diag, tangent, Bool.false_and, Bool.false_eq_true, ↓reduceIte,
    sig_symmetricmask, mulDiag, overlap, UInt64.or_zero, sig_parityinner, nest]

/-- Basis-result witness for every valid overlapping UInt64 mask in canonical sig,
n≤64. Width/containment restrict the geometric domain; the underlying unguarded
computational equation is stronger. Dimension64 is not a printable/dense-size claim. -/
theorem sig_apply₂_mul_overlap (n : Nat) (s A B : UInt64) (_width : n ≤ 64)
    (_validA : A &&& ~~~Bits.lowMask n = 0) (_validB : B &&& ~~~Bits.lowMask n = 0)
    (shared : A &&& B ≠ 0) :
    (sig n s).apply₂ .mul A B =
      .ok (.single (if parityjoin (sig n s).sigBits A B then -1 else 1) (A ^^^ B)) := by
  rw [apply₂, sig_mul_overlap n s A B shared]

/-- Actual canonical sig disjoint branch preserves bare positive versus stored negative.
It uses no metric-product recursion and makes no raw mask validity certificate. -/
theorem sig_mul_disjoint (n : Nat) (s A B : UInt64) (disjoint : A &&& B = 0) :
    (sig n s).mul A B =
      (if parityjoin (sig n s).sigBits A B then .single (-1) (A ^^^ B) else .blade (A ^^^ B)) := by
  have diag : (sig n s).isdiag = true := rfl
  have tangent : (sig n s).istangent = false := rfl
  have nest (r : BladeResult) : (sig n s).nestTangent 0 r = r := rfl
  simp only [mul, diag, tangent, Bool.false_and, Bool.false_eq_true, ↓reduceIte,
    sig_symmetricmask, mulDiag, disjoint, show ((0 : UInt64) == 0) = true from rfl,
    UInt64.or_zero, sig_parity, nest]
  cases parityjoin (sig n s).sigBits A B <;> simp only [Bool.false_eq_true, ↓reduceIte]
  · have pos : decide ((1 : Rat) < 0) = false := by decide +kernel
    simp only [pos]
    rfl
  · have neg : decide ((-1 : Rat) < 0) = true := by decide +kernel
    simp only [neg]
    rfl

/-- Derived canonical disjoint basis witness for every valid mask at n≤64, including
scalar mask0 and n0. Width/containment restrict the public geometric domain; the
unguarded computational reduction is stronger. Bare blade0 is not symbolic One. -/
theorem sig_apply₂_mul_disjoint (n : Nat) (s A B : UInt64) (_width : n ≤ 64)
    (_validA : A &&& ~~~Bits.lowMask n = 0) (_validB : B &&& ~~~Bits.lowMask n = 0)
    (disjoint : A &&& B = 0) :
    (sig n s).apply₂ .mul A B =
      .ok (if parityjoin (sig n s).sigBits A B then .single (-1) (A ^^^ B) else .blade (A ^^^ B)) := by
  rw [apply₂, sig_mul_disjoint n s A B disjoint]

end DirectSum.TensorBundle
