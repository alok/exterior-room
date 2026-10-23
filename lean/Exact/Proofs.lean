import Exact.Kernel

/-!
Exact integer laws for Exterior Room. The volume statements concern the
imported, executable Grassmann coefficient function, whose provider is frozen
by the upstream definition. Rendering and input/transport code are outside
these statements.
-/

namespace Exact.Proofs

open Grassmann DirectSum StaticVectors

abbrev Vector := Chain ℝ3 1 Int

/-- Componentwise sum in the same packed input representation. -/
def addVector (a b : Vector) : Vector :=
  ⟨Values.ofFn fun i => a.v.get i + b.v.get i⟩

/-- Reversing the inputs negates every exact exterior coordinate. -/
theorem wedge_antisymmetric (a b : Values Int 3) :
    Kernel.R3Wedge.formula a b =
      (Kernel.R3Wedge.formula b a).map (fun x => -x) := by
  apply Values.ext
  intro ⟨i, hi⟩
  have cases : i = 0 ∨ i = 1 ∨ i = 2 := by omega
  rcases cases with h | h | h <;> subst i <;>
    simp only [Values.get_map, Kernel.R3Wedge.formula, Values.get_ofFn] <;>
    grind

/-- The actual generated wedge kernel has the same antisymmetry. -/
theorem generated_wedge_antisymmetric (a b : Values Int 3) :
    Kernel.Gen.ℝ3.k_bin_wedge_c1_c1_c2 a b =
      (Kernel.Gen.ℝ3.k_bin_wedge_c1_c1_c2 b a).map (fun x => -x) := by
  rw [Kernel.R3Wedge.generated_formula, Kernel.R3Wedge.generated_formula]
  exact wedge_antisymmetric a b

/-- Swapping the first two vectors negates the actual signed-volume result. -/
theorem volume_swap (a b c : Vector) :
    Examples.OrientedVolume.coefficient b a c =
      -Examples.OrientedVolume.coefficient a b c := by
  simp only [Examples.OrientedVolume.coefficient_formula,
    Examples.OrientedVolume.orderedPolynomial]
  grind

/-- Repeated first vectors give exactly zero through the actual executable path. -/
theorem volume_self (a c : Vector) :
    Examples.OrientedVolume.coefficient a a c = 0 :=
  Examples.OrientedVolume.integer_selfFirst a c

/-- A third vector equal to the sum of the first two gives exactly zero volume. -/
theorem volume_add_dependent (a b : Vector) :
    Examples.OrientedVolume.coefficient a b (addVector a b) = 0 := by
  simp only [Examples.OrientedVolume.coefficient_formula,
    Examples.OrientedVolume.orderedPolynomial, addVector, Values.get_ofFn]
  grind

/-- The service wrapper preserves the proved sign reversal. -/
theorem service_volume_swap (a b c : Vec3) :
    volume b a c = -volume a b c :=
  volume_swap a.toChain b.toChain c.toChain

/-- Repeating a service input vector yields exact zero volume. -/
theorem service_volume_self (a c : Vec3) : volume a a c = 0 :=
  volume_self a.toChain c.toChain

/-- The service's generated self-wedge is a stored grade-two zero chain. -/
theorem service_wedge_self (a : Vec3) :
    wedge a a = TA.chain 2 ⟨zeroValues 3⟩ :=
  Kernel.R3Wedge.wedgeF_self Int.mul_comm Int.sub_self a.toChain

/-- Setting the third service vector to the sum of the first two gives zero. -/
theorem service_volume_add_dependent (a b : Vec3) :
    volume a b (a.add b) = 0 := by
  simp only [volume, Examples.OrientedVolume.coefficient_formula,
    Examples.OrientedVolume.orderedPolynomial, Vec3.toChain, Vec3.add,
    Values.get_ofFn]
  grind

end Exact.Proofs

#print axioms Grassmann.Kernel.R3Wedge.generated_formula
#print axioms Grassmann.Examples.OrientedVolume.coefficient_formula
#print axioms Grassmann.Examples.OrientedVolume.triple_eq_reference
#print axioms Exact.Proofs.generated_wedge_antisymmetric
#print axioms Exact.Proofs.volume_swap
#print axioms Exact.Proofs.volume_self
#print axioms Exact.Proofs.volume_add_dependent
#print axioms Exact.Proofs.service_volume_swap
#print axioms Exact.Proofs.service_volume_self
#print axioms Exact.Proofs.service_wedge_self
#print axioms Exact.Proofs.service_volume_add_dependent
