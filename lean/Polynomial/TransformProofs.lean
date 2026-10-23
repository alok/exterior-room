import Polynomial.Transform

namespace Polynomial.Mobius.Proofs

theorem apply_identity (v : Point) : apply identity v = v := by
  cases v
  simp [apply, identity]

theorem rows_apply (g : Matrix) (v : Point) : rowsApply g v = apply g v := by
  simp [rowsApply, rows, apply] <;> grind

theorem determinant_multiply (g h : Matrix) :
    determinant (multiply g h) = determinant g * determinant h := by
  simp only [determinant, multiply]
  grind

/-- Composition agrees with the source's left-composed action. -/
theorem apply_multiply (g h : Matrix) (v : Point) :
    apply (multiply g h) v = apply g (apply h v) := by
  simp only [apply, multiply]
  congr 1 <;> grind

/-- Dividing the image coordinates by det M preserves the discriminant exactly. -/
theorem delta_apply (g : Matrix) (v : Point) :
    delta (apply g v) = determinant g * determinant g * delta v := by
  simp only [delta, apply, determinant]
  grind

/-- Applying the same normalized action to a normal and point preserves incidence. -/
theorem incidence_apply (g : Matrix) (n v : Point) :
    incidence (apply g n) (apply g v) = determinant g * determinant g * incidence n v := by
  simp only [incidence, apply, determinant]
  grind

theorem apply_scale (g : Matrix) (k : Int) (v : Point) :
    apply g (scale k v) = scale k (apply g v) := by
  simp only [apply, scale]
  congr 1 <;> grind

/-- The adjugate reverses the action, with its explicit shared denominator. -/
theorem apply_adjugate (g : Matrix) (v : Point) :
    apply (adjugate g) (apply g v) = scale (determinant g * determinant g) v := by
  simp only [apply, adjugate, scale, determinant]
  congr 1 <;> grind

end Polynomial.Mobius.Proofs

#print axioms Polynomial.Mobius.Proofs.apply_identity
#print axioms Polynomial.Mobius.Proofs.rows_apply
#print axioms Polynomial.Mobius.Proofs.determinant_multiply
#print axioms Polynomial.Mobius.Proofs.apply_multiply
#print axioms Polynomial.Mobius.Proofs.delta_apply
#print axioms Polynomial.Mobius.Proofs.incidence_apply
#print axioms Polynomial.Mobius.Proofs.apply_scale
#print axioms Polynomial.Mobius.Proofs.apply_adjugate
