/-
Typed Single natural powers through the dynamic TensorTerm dispatch
(Julia Grassmann src/algebra.jl:424-438). The result is TA so One/Single/Zero
kinds are preserved, including the existing corrected term-power-period4 policy.
The existing Float typed power surface remains Couple-valued.
-/
import Grassmann.Dynamic.Division

namespace Grassmann

open DirectSum AbstractTensors

namespace Single

variable {V : TensorBundle} {G : Nat} {α : Type} [Coeff α] [Kernels V]

/-- Natural power of a typed Single with dynamic result kinds (Julia algebra.jl:424-438).
Uses the existing term algorithm and metric corrections; raw masks are not validated here. -/
@[specialize] def powNat (s : Single V G α) (n : Nat) : TA V α :=
  TA.powNat (TA.ofSingle s) n

end Single

-- Concrete exact coefficients avoid overlapping the existing Float-to-Couple instance.
instance {V : TensorBundle} [Kernels V] {G : Nat} :
    HPow (Single V G Rat) Nat (TA V Rat) := ⟨Single.powNat⟩

instance {V : TensorBundle} [Kernels V] {G : Nat} :
    HPow (Single V G Int) Nat (TA V Int) := ⟨Single.powNat⟩

end Grassmann
