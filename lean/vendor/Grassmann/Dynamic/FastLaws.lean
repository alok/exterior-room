/- Raw same-mask Single multiplication refinement; no coefficient algebra laws. -/
import Grassmann.Dynamic.BladeInverseLaws
import Grassmann.Dynamic.Ops

namespace Grassmann

open DirectSum AbstractTensors

namespace TA

/-- Raw fast/reference equality for shared-mask stored Singles, with actual stored ±1
basis-result evidence. Every Coeff input and selector is covered without algebraic laws;
both signs preserve (x*y)*ofRat(sign), including the positive overlap factor. -/
theorem mulF_single_overlap {V : TensorBundle} {α : Type} [Coeff α]
    [Kernels V] [DynKernels V] (A B : UInt64)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (shared : A &&& B ≠ 0)
    (basis : V.apply₂ .mul A B =
      .ok (.single (if parityjoin V.sigBits A B then -1 else 1) (A ^^^ B))) (x y : α) :
    mulF (.single A x : TA V α) (.single B y) = mul (.single A x) (.single B y) := by
  by_cases fast : DynKernels.fast V = true
  · rw [mul_single_blade_term A B basis (.stored _)]
    have overlap : (A &&& B == 0) = false := by simp [shared]
    rcases metric with metric | ⟨neg, metric⟩ <;>
      simp only [mulF, prodF, fast, ↓reduceIte, metric, overlap,
        show (POp.mul == POp.mul) = true from rfl, Bool.false_eq_true]
  · have slow : DynKernels.fast V = false := by cases h : DynKernels.fast V <;> simp_all
    simp only [mulF, prodF, slow, Bool.false_eq_true, ↓reduceIte]
    rfl

/-- Rat's actual Coeff cast is identity, so the shared-arm coefficient formula is exact
without a multiplication-law or Field premise. -/
theorem mulF_single_overlap_rat {V : TensorBundle} [Kernels V] [DynKernels V]
    (A B : UInt64) (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (shared : A &&& B ≠ 0)
    (basis : V.apply₂ .mul A B =
      .ok (.single (if parityjoin V.sigBits A B then -1 else 1) (A ^^^ B))) (x y : Rat) :
    mulF (.single A x : TA V Rat) (.single B y) =
      .single (A ^^^ B) ((x*y)*(if parityjoin V.sigBits A B then -1 else 1)) := by
  rw [mulF_single_overlap A B metric shared basis]
  exact mul_single_blade_term A B basis (.stored _) x y

/-- Actual Int Coeff conversion truncates general rationals, but is exactly coherent
on these two integral signs. No law for arbitrary rational casts is asserted. -/
theorem ofRat_sign_int (neg : Bool) :
    (Coeff.ofRat (if neg then (-1 : Rat) else 1) : Int) = (if neg then -1 else 1) := by
  cases neg <;> rfl

/-- Int shared-arm formula through the actual tdiv cast at ±1; coefficients remain
unbounded Lean Int, so this does not assert Julia Int64 overflow equivalence. -/
theorem mulF_single_overlap_int {V : TensorBundle} [Kernels V] [DynKernels V]
    (A B : UInt64) (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (shared : A &&& B ≠ 0)
    (basis : V.apply₂ .mul A B =
      .ok (.single (if parityjoin V.sigBits A B then -1 else 1) (A ^^^ B))) (x y : Int) :
    mulF (.single A x : TA V Int) (.single B y) =
      .single (A ^^^ B) ((x*y)*(if parityjoin V.sigBits A B then -1 else 1)) := by
  rw [mulF_single_overlap A B metric shared basis,
    mul_single_blade_term A B basis (.stored _) x y]
  simp only [ofRat_sign_int]

/-- Disjoint masks remove the shared negative-generator factor from actual parityjoin.
This bit identity uses no metric or coefficient laws. -/
theorem parityjoin_disjoint (s A B : UInt64) (disjoint : A &&& B = 0) :
    parityjoin s A B = Bits.reorderParity A B := by
  simp only [parityjoin, disjoint, UInt64.zero_and]
  cases Bits.reorderParity A B <;> rfl

/-- Raw fast/reference equality on the disjoint stored-Single arm for arbitrary Coeff
inputs and selectors. The witness describes actual basis dispatch, not the target product.
Bare positive scaling remains x*y; stored negative scaling remains (x*y)*ofRat(-1). -/
theorem mulF_single_disjoint {V : TensorBundle} {α : Type} [Coeff α]
    [Kernels V] [DynKernels V] (A B : UInt64)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (disjoint : A &&& B = 0)
    (basis : V.apply₂ .mul A B =
      .ok (if parityjoin V.sigBits A B then .single (-1) (A ^^^ B) else .blade (A ^^^ B)))
    (x y : α) :
    mulF (.single A x : TA V α) (.single B y) = mul (.single A x) (.single B y) := by
  by_cases fast : DynKernels.fast V = true
  · cases par : parityjoin V.sigBits A B with
    | false =>
      simp only [par, Bool.false_eq_true, ↓reduceIte] at basis
      rw [mul_single_blade_term A B basis .bare]
      rcases metric with metric | ⟨neg, metric⟩ <;>
        simp only [mulF, prodF, fast, ↓reduceIte, metric, disjoint, par,
          show ((0 : UInt64) == 0) = true from rfl,
          show (POp.mul == POp.mul) = true from rfl, Bool.false_eq_true]
    | true =>
      simp only [par, ↓reduceIte] at basis
      rw [mul_single_blade_term A B basis (.stored (-1))]
      rcases metric with metric | ⟨neg, metric⟩ <;>
        simp only [mulF, prodF, fast, ↓reduceIte, metric, disjoint, par,
          show ((0 : UInt64) == 0) = true from rfl,
          show (POp.mul == POp.mul) = true from rfl]
  · have slow : DynKernels.fast V = false := by cases h : DynKernels.fast V <;> simp_all
    simp only [mulF, prodF, slow, Bool.false_eq_true, ↓reduceIte]
    rfl

/-- Actual scalar-basis reordering/metric parity is false for every signature bit mask. -/
theorem parityjoin_zero_mask (s : UInt64) : parityjoin s 0 0 = false := by
  simp only [parityjoin, UInt64.zero_and]
  rfl

/-- Stored scalar Singles refine raw fast/reference multiplication for arbitrary coefficients
and selectors. The bare scalar square scales to x*y without any ofRat-one or identity law. -/
theorem mulF_zero_mask_single {V : TensorBundle} {α : Type} [Coeff α]
    [Kernels V] [DynKernels V]
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (square : V.apply₂ .mul 0 0 = .ok (.blade 0)) (x y : α) :
    mulF (.single 0 x : TA V α) (.single 0 y) = mul (.single 0 x) (.single 0 y) := by
  by_cases fast : DynKernels.fast V = true
  · rw [mul_single_scalar_square 0 square .bare]
    rcases metric with metric | ⟨neg, metric⟩ <;>
      simp only [mulF, prodF, fast, ↓reduceIte, metric, UInt64.xor_self,
        UInt64.and_self, parityjoin_zero_mask, show ((0 : UInt64) == 0) = true from rfl,
        show (POp.mul == POp.mul) = true from rfl, Bool.false_eq_true]
  · have slow : DynKernels.fast V = false := by cases h : DynKernels.fast V <;> simp_all
    simp only [mulF, prodF, slow, Bool.false_eq_true, ↓reduceIte]
    rfl

/-- The executable scalar inverse uses only Coeff and Div, with no kernel or unit law. -/
theorem invTerm_scalar {V : TensorBundle} {α : Type} [Coeff α] [Div α] (x : α) :
    invTerm (V := V) 0 x = .single 0 (Coeff.one / x) := rfl

/-- Public scalar Rat inverse products are stored Single 1 under the actual bare-square
witness and x≠0. The coefficient cancellation is inherited from the exact cpow proof. -/
theorem mul_invTerm_scalar_rat_pair {V : TensorBundle} [Kernels V] [DynKernels V]
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (square : V.apply₂ .mul 0 0 = .ok (.blade 0)) (x : Rat) (hx : x ≠ 0) :
    (.single 0 x : TA V Rat) * invTerm 0 x = .single 0 1 ∧
      (invTerm 0 x : TA V Rat) * .single 0 x = .single 0 1 := by
  change mulF (.single 0 x) (invTerm 0 x) = _ ∧ mulF (invTerm 0 x) (.single 0 x) = _
  rw [invTerm_scalar, mulF_zero_mask_single metric square,
    mulF_zero_mask_single metric square, mul_single_scalar_square 0 square .bare,
    mul_single_scalar_square 0 square .bare]
  have cancel := rat_cpow_inverse_cancel x hx 1
  change (1*x) * (1*(1/x)) = 1 at cancel
  have xy : x*(1/x) = 1 := by simpa only [Rat.one_mul] using cancel
  constructor
  · exact congrArg (single 0) xy
  · exact congrArg (single 0) ((Rat.mul_comm (1/x) x).trans xy)

/-- The actual fast and reference products agree as raw TA values for stored Singles
sharing a nonzero mask in a Euclidean/signature metric with the stated square witness.
All coefficients and DynKernels selectors are covered; no Coeff algebraic law is used. -/
theorem mulF_single_same_mask {V : TensorBundle} {α : Type} [Coeff α]
    [Kernels V] [DynKernels V] (b : UInt64)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg) (hb : b ≠ 0)
    (square : V.apply₂ .mul b b =
      .ok (.single (if parityjoin V.sigBits b b then -1 else 1) 0)) (x y : α) :
    mulF (.single b x : TA V α) (.single b y) = mul (.single b x) (.single b y) := by
  by_cases fast : DynKernels.fast V = true
  · rw [mul_single_square b _ square]
    have shared : (b == 0) = false := by simp [hb]
    rcases metric with metric | ⟨neg, metric⟩ <;>
      simp only [mulF, prodF, fast, ↓reduceIte, metric,
        UInt64.xor_self, UInt64.and_self, shared,
        show (POp.mul == POp.mul) = true from rfl, Bool.false_eq_true]
  · have slow : DynKernels.fast V = false := by cases h : DynKernels.fast V <;> simp_all
    simp only [mulF, prodF, slow, Bool.false_eq_true, ↓reduceIte]
    rfl

/-- invTerm keeps the nonzero mask, so the raw bridge applies in both operand orders.
This operations-only refinement includes zero coefficients/denominators, without a unit claim. -/
theorem mulF_invTerm_pair {V : TensorBundle} {α : Type} [Coeff α] [Div α]
    [Kernels V] [DynKernels V] (b : UInt64)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg) (hb : b ≠ 0)
    (square : V.apply₂ .mul b b =
      .ok (.single (if parityjoin V.sigBits b b then -1 else 1) 0)) (x : α) :
    mulF (.single b x : TA V α) (invTerm b x) = mul (.single b x) (invTerm b x) ∧
      mulF (invTerm b x : TA V α) (.single b x) = mul (invTerm b x) (.single b x) := by
  let y : α := (if revSign b then -Coeff.one else Coeff.one) /
    (Coeff.ofRat (abs2Inv V b) * x)
  have shape : invTerm (V := V) b x = .single b y := by
    simp only [invTerm, show (b == 0) = false by simp [hb], Bool.false_eq_true, ↓reduceIte]
    rfl
  rw [shape]
  exact ⟨mulF_single_same_mask b metric hb square x y,
    mulF_single_same_mask b metric hb square y x⟩

/-- Public dynamic TA multiplication transfers the existing Rat two-sided inverse proof.
The raw result remains stored scalar Single 1 under explicit nonzero metric/coefficient facts. -/
theorem mul_invTerm_rat_pair {V : TensorBundle} [Kernels V] [DynKernels V] (b : UInt64)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg) (hb : b ≠ 0)
    (square : V.apply₂ .mul b b =
      .ok (.single (if parityjoin V.sigBits b b then -1 else 1) 0))
    (coherent : (if parityjoin V.sigBits b b then (-1 : Rat) else 1) *
      (if revSign b then -1 else 1) = abs2Inv V b)
    (hd : abs2Inv V b ≠ 0) (x : Rat) (hx : x ≠ 0) :
    (.single b x : TA V Rat) * invTerm b x = .single 0 1 ∧
      (invTerm b x : TA V Rat) * .single b x = .single 0 1 := by
  change mulF (.single b x) (invTerm b x) = _ ∧ mulF (invTerm b x) (.single b x) = _
  have bridge := mulF_invTerm_pair b metric hb square x
  have inverse := invTerm_rat_mul_pair b _ x hb square coherent hd hx
  exact ⟨bridge.1.trans inverse.1, bridge.2.trans inverse.2⟩

end TA

namespace Single

/-- Checked scalar Rat -1 passes the real nonzero guard and preserves the scalar invTerm.
Exponent one returns its input; no metric, grade validation or geometric unit claim is needed. -/
theorem powInt?_scalar_rat_neg_one {V : TensorBundle} [Kernels V] (x : Rat) (hx : x ≠ 0) :
    (scalar (V := V) x) ^? (-1) = some (TA.invTerm 0 x) := by
  have guard : Coeff.isZero (scalar (V := V) x).invDenominator = false := by
    change (x == 0) = false
    simp [hx]
  rw [powInt?_negative _ (-1) (by decide) guard]
  change some (TA.powNat (TA.invTerm 0 x) 1) = _
  simp only [TA.invTerm, BEq.rfl, ↓reduceIte, TA.powNat, ↓reduceDIte]

/-- Checked nonzero Rat scalar -1 has both inverse directions under public dynamic TA *,
preserving raw stored Single 1 under the explicit scalar-square/metric witnesses. -/
theorem powInt?_scalar_rat_public_mul_pair {V : TensorBundle} [Kernels V] [DynKernels V]
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg)
    (square : V.apply₂ .mul 0 0 = .ok (.blade 0)) (x : Rat) (hx : x ≠ 0) :
    ((scalar (V := V) x) ^? (-1)).map (fun inv =>
      ((TA.ofSingle (scalar (V := V) x) : TA V Rat) * inv,
        inv * TA.ofSingle (scalar (V := V) x))) = some (.single 0 1, .single 0 1) := by
  rw [powInt?_scalar_rat_neg_one x hx, Option.map_some]
  have pair := TA.mul_invTerm_scalar_rat_pair metric square x hx
  change some ((.single 0 x : TA V Rat) * TA.invTerm 0 x,
    (TA.invTerm 0 x : TA V Rat) * .single 0 x) = _
  rw [pair.1, pair.2]

/-- Checked Rat -1 yields a two-sided inverse under public dynamic TA *, in the same-mask
Euclidean/signature witness domain. Raw mask/grade validity and wider products are not assumed. -/
theorem powInt?_rat_public_mul_pair {V : TensorBundle} {G : Nat} [Kernels V] [DynKernels V]
    (s : Single V G Rat)
    (metric : V.metric = .euclid ∨ ∃ neg, V.metric = .signature neg) (hb : s.bits ≠ 0)
    (square : V.apply₂ .mul s.bits s.bits =
      .ok (.single (if parityjoin V.sigBits s.bits s.bits then -1 else 1) 0))
    (coherent : (if parityjoin V.sigBits s.bits s.bits then (-1 : Rat) else 1) *
      (if TA.revSign s.bits then -1 else 1) = TA.abs2Inv V s.bits)
    (hd : TA.abs2Inv V s.bits ≠ 0) (hx : s.val ≠ 0) :
    (s ^? (-1)).map (fun inv => ((TA.ofSingle s : TA V Rat) * inv, inv * TA.ofSingle s)) =
      some (.single 0 1, .single 0 1) := by
  rw [powInt?_neg_one_rat s hb hd hx, Option.map_some]
  have pair := TA.mul_invTerm_rat_pair s.bits metric hb square coherent hd s.val hx
  change some ((.single s.bits s.val : TA V Rat) * TA.invTerm s.bits s.val,
    (TA.invTerm s.bits s.val : TA V Rat) * .single s.bits s.val) = _
  rw [pair.1, pair.2]

end Single

end Grassmann
