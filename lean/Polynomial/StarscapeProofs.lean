/-
SPDX-License-Identifier: GPL-3.0-or-later
Kernel-checked facts behind the Starscape interactions, ported from alok/starscape (lean/Starscape/*.lean) to this
service's `Point`, `Matrix`, `apply` and `incidence`. Claude (Opus 5.5), 2026-10-24.
-/
import Polynomial.TransformProofs

namespace Polynomial.Starscape

open Polynomial.Mobius

/-- The homogeneous form `a x² + b x y + c y²` at `(x, y)`. -/
def eval (p : Point) (x y : Int) : Int := p.a * x * x + p.b * x * y + p.c * y * y

/-- The matrix acting on a root vector `(x, y)`: `x/y ↦ (px + qy)/(rx + sy)`. -/
def act (g : Matrix) (x y : Int) : Int × Int := (g.p * x + g.q * y, g.r * x + g.s * y)

/-- **Roots move by `g`.** `apply g` is the numerator of `Q ∘ g⁻¹`, so evaluating it at `g · v` gives `det(g)²`
times `Q(v)`. In particular `Q` vanishes at `v` exactly when `apply g Q` vanishes at `g · v`: the identity
`R(ρ(A)f) = A · R(f)` behind dragging the roots pane. -/
theorem eval_apply (g : Matrix) (p : Point) (x y : Int) :
    eval (apply g p) (act g x y).1 (act g x y).2 = determinant g ^ 2 * eval p x y := by
  unfold eval apply act determinant; grind

/-- For `g ∈ SL₂(ℤ)` the form is carried along exactly. -/
theorem eval_apply_sl2 (g : Matrix) (h : determinant g = 1) (p : Point) (x y : Int) :
    eval (apply g p) (act g x y).1 (act g x y).2 = eval p x y := by
  rw [eval_apply, h]; grind

/-- `(qx − p)(sx − r)`, the Farey edge between `p/q` and `r/s`. -/
def farey (p q r s : Int) : Point := ⟨q * s, -(q * r + p * s), p * r⟩

/-- Farey edges are planes of `Δ = 1` dust: the discriminant of an edge is `(ps − qr)²`. -/
theorem delta_farey (p q r s : Int) : delta (farey p q r s) = (p * s - q * r) ^ 2 := by
  unfold farey delta; grind

/-- The action maps the edge between `p/q` and `r/s` to the edge between their images, so `SL₂(ℤ)` permutes the
Farey tessellation. -/
theorem apply_farey (g : Matrix) (p q r s : Int) :
    apply g (farey p q r s) =
      farey (g.p * p + g.q * q) (g.r * p + g.s * q) (g.p * r + g.q * s) (g.r * r + g.s * s) := by
  unfold apply farey
  show Point.mk _ _ _ = Point.mk _ _ _
  simp only [Point.mk.injEq]
  refine ⟨?_, ?_, ?_⟩ <;> grind

/-! Parity fixtures, checked by the kernel. -/

/-- Snap absorbs `T⁴`: `(13, 20, 34) ↦ (13, −84, 162)`, with `Δ = −1368` unchanged. -/
theorem fixture_T4 : apply ⟨1, 4, 0, 1⟩ ⟨13, 20, 34⟩ = ⟨13, -84, 162⟩ ∧ delta ⟨13, -84, 162⟩ = -1368 := by decide

/-- One `T` sends `(13, 20, 34)` to `(13, −6, 27)`. -/
theorem fixture_T : apply ⟨1, 1, 0, 1⟩ ⟨13, 20, 34⟩ = ⟨13, -6, 27⟩ := by decide

/-- `x² + 1` and `x² + x + 1` span `2a − 2c = 0`, the unit circle. -/
theorem fixture_unit_circle : pairNormal ⟨1, 0, 1⟩ ⟨1, 1, 1⟩ = ⟨2, 0, -2⟩ := by decide

#print axioms eval_apply
#print axioms eval_apply_sl2
#print axioms delta_farey
#print axioms apply_farey
#print axioms fixture_T4
#print axioms fixture_unit_circle

end Polynomial.Starscape
