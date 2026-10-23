/- Valid canonical signature Single overlap bridge without a supplied basis witness. -/
import DirectSum.SignatureLaws
import Grassmann.Dynamic.FastLaws

namespace Grassmann.TA

open DirectSum

/-- Raw fast/reference equality for all valid overlapping stored Singles in canonical
sig n s, n≤64, every operations-only coefficient and selector. The actual basis
witness is derived from the constructor and metric recursion, not supplied by callers. -/
theorem mulF_single_sig_overlap {α : Type} [Coeff α] (n : Nat) (s A B : UInt64)
    [Kernels (TensorBundle.sig n s)] [DynKernels (TensorBundle.sig n s)]
    (width : n ≤ 64) (validA : valid (TensorBundle.sig n s) A = true)
    (validB : valid (TensorBundle.sig n s) B = true) (shared : A &&& B ≠ 0) (x y : α) :
    mulF (.single A x : TA (TensorBundle.sig n s) α) (.single B y) =
      mul (.single A x) (.single B y) := by
  have containedA : A &&& ~~~Bits.lowMask n = 0 := by
    simpa only [valid, Layout.contains, Bool.and_true, beq_iff_eq, TensorBundle.sig] using validA
  have containedB : B &&& ~~~Bits.lowMask n = 0 := by
    simpa only [valid, Layout.contains, Bool.and_true, beq_iff_eq, TensorBundle.sig] using validB
  exact mulF_single_overlap A B (Or.inr ⟨s &&& Bits.lowMask n,rfl⟩) shared
    (TensorBundle.sig_apply₂_mul_overlap n s A B width containedA containedB shared) x y

/-- Raw canonical sig disjoint Single bridge with derived bare/stored basis evidence.
Every operations-only coefficient and selector is covered; positive scaling is x*y,
negative (x*y)*ofRat(-1), with no identity/cast or algebra law requirement. -/
theorem mulF_single_sig_disjoint {α : Type} [Coeff α] (n : Nat) (s A B : UInt64)
    [Kernels (TensorBundle.sig n s)] [DynKernels (TensorBundle.sig n s)]
    (width : n ≤ 64) (validA : valid (TensorBundle.sig n s) A = true)
    (validB : valid (TensorBundle.sig n s) B = true) (disjoint : A &&& B = 0) (x y : α) :
    mulF (.single A x : TA (TensorBundle.sig n s) α) (.single B y) =
      mul (.single A x) (.single B y) := by
  have containedA : A &&& ~~~Bits.lowMask n = 0 := by
    simpa only [valid, Layout.contains, Bool.and_true, beq_iff_eq, TensorBundle.sig] using validA
  have containedB : B &&& ~~~Bits.lowMask n = 0 := by
    simpa only [valid, Layout.contains, Bool.and_true, beq_iff_eq, TensorBundle.sig] using validB
  exact mulF_single_disjoint A B (Or.inr ⟨s &&& Bits.lowMask n,rfl⟩) disjoint
    (TensorBundle.sig_apply₂_mul_disjoint n s A B width containedA containedB disjoint) x y

/-- Raw fast/reference equality for every pair of valid stored Singles in canonical sig,
n≤64. The disjoint/overlap split closes only this fragment, preserving distinct bare/
stored scaling formulas without claiming container, field or geometric group laws. -/
theorem mulF_single_sig {α : Type} [Coeff α] (n : Nat) (s A B : UInt64)
    [Kernels (TensorBundle.sig n s)] [DynKernels (TensorBundle.sig n s)]
    (width : n ≤ 64) (validA : valid (TensorBundle.sig n s) A = true)
    (validB : valid (TensorBundle.sig n s) B = true) (x y : α) :
    mulF (.single A x : TA (TensorBundle.sig n s) α) (.single B y) =
      mul (.single A x) (.single B y) := by
  by_cases shared : A &&& B = 0
  · exact mulF_single_sig_disjoint n s A B width validA validB shared x y
  · exact mulF_single_sig_overlap n s A B width validA validB shared x y

end Grassmann.TA
