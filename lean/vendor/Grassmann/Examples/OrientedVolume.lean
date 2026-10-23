/- Renderer-neutral ordered triple exterior product, on the actual frozen R3 TA path.
Exact signed-volume laws require separate coherent scalar facts. -/
import Grassmann.Kernel.R3TopWedgeLaws

namespace Grassmann.Examples.OrientedVolume
open DirectSum StaticVectors AbstractTensors

/-- Actual two-stage ((a∧b)∧c), with concrete generated provider and selector frozen. -/
@[specialize] def triple {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) : TA ℝ3 α :=
  @TA.wedgeF ℝ3 α _ Kernel.Gen.ℝ3.instKernels instDynKernelsℝ3
    (@TA.wedgeF ℝ3 α _ Kernel.Gen.ℝ3.instKernels instDynKernelsℝ3
      (.chain 1 a) (.chain 1 b)) (.chain 1 c)

/-- Actual e123 coefficient of the ordered triple, including coefficient zero. -/
@[specialize] def coefficient {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) : α :=
  (triple a b c).coeff 7

/-- Ordered polynomial on the same packed coordinates; no determinant law for arbitrary Coeff. -/
@[specialize] def orderedPolynomial {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) : α :=
  ((a.v.get ⟨0, by decide⟩ * b.v.get ⟨1, by decide⟩ -
      a.v.get ⟨1, by decide⟩ * b.v.get ⟨0, by decide⟩) * c.v.get ⟨2, by decide⟩ -
    (a.v.get ⟨0, by decide⟩ * b.v.get ⟨2, by decide⟩ -
      a.v.get ⟨2, by decide⟩ * b.v.get ⟨0, by decide⟩) * c.v.get ⟨1, by decide⟩) +
    (a.v.get ⟨1, by decide⟩ * b.v.get ⟨2, by decide⟩ -
      a.v.get ⟨2, by decide⟩ * b.v.get ⟨1, by decide⟩) * c.v.get ⟨0, by decide⟩

/-- Every arbitrary triple has the actual stored top-grade representation. -/
theorem triple_formula {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) :
    triple a b c = .chain 3 ⟨Kernel.R3TopWedge.formula (Kernel.R3Wedge.formula a.v b.v) c.v⟩ := by
  unfold triple
  rw [Kernel.R3Wedge.wedgeF_formula]
  exact Kernel.R3TopWedge.fast21 ⟨Kernel.R3Wedge.formula a.v b.v⟩ c

/-- The executable coefficient equals the ordered polynomial for every operations-only triple. -/
theorem coefficient_formula {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) :
    coefficient a b c = orderedPolynomial a b c := by
  unfold coefficient
  rw [triple_formula, Kernel.R3TopWedge.coeff_top]
  simp [Kernel.R3TopWedge.formula, Kernel.R3TopWedge.coordinate, Kernel.R3Wedge.formula,
    orderedPolynomial, Values.get_ofFn] <;> rfl

/-- Actual frozen two-stage fast/reference RAW equality, not geometric associativity. -/
theorem triple_eq_reference {α : Type} [Coeff α] (a b c : Chain ℝ3 1 α) :
    triple a b c =
      @TA.wedge ℝ3 α _ Kernel.Gen.ℝ3.instKernels
        (@TA.wedge ℝ3 α _ Kernel.Gen.ℝ3.instKernels (.chain 1 a) (.chain 1 b))
        (.chain 1 c) := by
  rw [triple_formula, Kernel.R3Wedge.wedge_formula]
  exact (Kernel.R3TopWedge.reference21 ⟨Kernel.R3Wedge.formula a.v b.v⟩ c).symm

/-- Repeated first vectors cancel under four facts on the actual operations.
No Field, division, broad scalar law class or Float instance is assumed. -/
theorem coefficient_selfFirst {α : Type} [Coeff α]
    (comm : ∀ x y : α, x*y = y*x) (cancel : ∀ x : α, x-x = Coeff.zero)
    (zeroMul : ∀ x : α, Coeff.zero*x = Coeff.zero) (zeroAdd : (Coeff.zero : α)+Coeff.zero = Coeff.zero)
    (a c : Chain ℝ3 1 α) : coefficient a a c = Coeff.zero := by
  rw [coefficient_formula]
  simp [orderedPolynomial, comm, cancel, zeroMul, zeroAdd]

/-- Core exact Rat operations discharge those four facts for arbitrary inputs. -/
theorem rational_selfFirst (a c : Chain ℝ3 1 Rat) : coefficient a a c = 0 :=
  coefficient_selfFirst Rat.mul_comm (fun x => by change x-x = (0 : Rat); exact Rat.sub_self) Rat.zero_mul (by change (0 : Rat)+0 = 0; exact Rat.zero_add 0) a c

/-- Core unbounded Int operations discharge the same facts, with no division. -/
theorem integer_selfFirst (a c : Chain ℝ3 1 Int) : coefficient a a c = 0 :=
  coefficient_selfFirst Int.mul_comm Int.sub_self Int.zero_mul rfl a c

end Grassmann.Examples.OrientedVolume
