import Polynomial.Core
import Polynomial.TransformProofs

namespace Polynomial.Proofs

/-- The displayed coordinate ball is exactly b²+2a²+2c². -/
theorem display_norm (p : Point) : dot (display p) (display p) = normSquared p := by
  simp only [dot, display, normSquared]
  grind

/-- The double cone is the discriminant-zero locus in displayed coordinates. -/
theorem discriminant_lorentz (p : Point) :
    (display p).x*(display p).x - (display p).y*(display p).y +
      (display p).z*(display p).z = delta p := by
  simp only [display, delta]
  grind

/-- Multiplicity is retained: scaling coefficients scales the discriminant quadratically. -/
theorem delta_scale (k : Int) (p : Point) : delta (scale k p) = k*k*delta p := by
  simp only [delta, scale]
  grind

theorem delta_neg (p : Point) : delta (scale (-1) p) = delta p := by
  rw [delta_scale]
  grind

/-- The coefficient-space and displayed Euclidean plane tests agree exactly. -/
theorem plane_display (n p : Point) : dot (planeNormal n) (display p) = incidence n p := by
  simp only [dot, planeNormal, display, incidence]
  grind

/-- Actual unnormalized pair normals contain the first coefficient vector. -/
theorem pair_incidence_first (p q : Point) : incidence (pairNormal p q) p = 0 := by
  simp only [incidence, pairNormal, cross, dual]
  grind

/-- Actual unnormalized pair normals contain the second coefficient vector. -/
theorem pair_incidence_second (p q : Point) : incidence (pairNormal p q) q = 0 := by
  simp only [incidence, pairNormal, cross, dual]
  grind

theorem incidence_scale (k : Int) (n p : Point) : incidence (scale k n) p = k*incidence n p := by
  simp only [incidence, scale]
  grind

/-- Removing a nonzero common scale cannot change whether a point lies in a plane. -/
theorem incidence_unscale (k : Int) (n p : Point) (hk : k ≠ 0)
    (h : incidence (scale k n) p = 0) : incidence n p = 0 := by
  rw [incidence_scale] at h
  exact (Int.mul_eq_zero.mp h).resolve_left hk

end Polynomial.Proofs

#print axioms Polynomial.Proofs.display_norm
#print axioms Polynomial.Proofs.discriminant_lorentz
#print axioms Polynomial.Proofs.delta_scale
#print axioms Polynomial.Proofs.delta_neg
#print axioms Polynomial.Proofs.plane_display
#print axioms Polynomial.Proofs.pair_incidence_first
#print axioms Polynomial.Proofs.pair_incidence_second
#print axioms Polynomial.Proofs.incidence_unscale
