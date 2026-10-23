/-
Checked typed Single integer powers: finite denominator domain for the existing
inverse formula (Julia algebra.jl:536-546/700-715), followed by TA.powNat.
Runtime negative Julia powers have the documented term-power-period4 defect.
-/
import Grassmann.Dynamic.SinglePow

namespace Grassmann

open DirectSum AbstractTensors

namespace Single

variable {V : TensorBundle} {G : Nat} {α : Type} [Coeff α] [Kernels V]

/-- The exact denominator consumed by TA.invTerm: scalar x, or abs2Inv(B)*x.
This is computational data; nonzero alone does not establish a generic unit. -/
@[specialize] def invDenominator (s : Single V G α) : α :=
  if s.bits == 0 then s.val else Coeff.ofRat (TA.abs2Inv V s.bits) * s.val

/-- Checked integer powers with dynamic kinds. Nonnegative powers are always some;
negative powers reject a zero inverse denominator before division. No mask validation
or generic invertibility law is implied. Existing total TA/Float APIs are unchanged. -/
@[specialize] def powInt? [Div α] (s : Single V G α) (i : Int) : Option (TA V α) :=
  if i ≥ 0 then some (s.powNat i.toNat)
  else if Coeff.isZero s.invDenominator then none
  else some (TA.powNat (TA.invTerm s.bits s.val) i.natAbs)

end Single

/-- Explicit checked Single integer power, directly calling powInt? rather than HPow.
An expected TA result cannot select the legacy total power via base coercion. -/
scoped infixr:80 " ^? " => Single.powInt?

/-- Exact Rat typed integer powers use the explicitly partial finite-domain API. -/
instance {V : TensorBundle} [Kernels V] {G : Nat} :
    HPow (Single V G Rat) Int (Option (TA V Rat)) := ⟨Single.powInt?⟩

end Grassmann
