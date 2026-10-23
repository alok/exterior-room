/-
Exact natural-power refinements for actual Coeff folds and typed Single dispatch.
Executable Coeff operations do not entail algebraic laws: each needed law is explicit.
-/
import Grassmann.Dynamic.SinglePow
import Grassmann.Dynamic.Laws

namespace Grassmann

open DirectSum AbstractTensors

namespace TA

variable {α : Type} [Coeff α]

/-- The executable coefficient fold has zero factors at exponent zero; no laws needed. -/
@[simp] theorem cpow_zero (x : α) : cpow x 0 = Coeff.one := rfl

/-- One more factor appends a right multiplication in the actual List.range left fold. -/
theorem cpow_succ (x : α) (n : Nat) : cpow x (n + 1) = cpow x n * x := by
  simp only [cpow, List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]

/-- Addition of exponents for actual coefficient powers needs only associative
Coeff multiplication and its right identity. No commutativity, addition or division. -/
theorem cpow_add (assoc : ∀ a b c : α, (a * b) * c = a * (b * c))
    (right_id : ∀ a : α, a * Coeff.one = a) (x : α) (m n : Nat) :
    cpow x (m + n) = cpow x m * cpow x n := by
  induction n with
  | zero => simp only [Nat.add_zero, cpow_zero, right_id]
  | succ n ih => rw [Nat.add_succ, cpow_succ, cpow_succ, ih, assoc]

end TA

namespace Single

variable {V : TensorBundle} {G : Nat} {α : Type} [Coeff α] [Kernels V]

/-- A typed Single to exponent zero is the dynamic basis One, regardless of its value. -/
@[simp] theorem powNat_zero (s : Single V G α) : s.powNat 0 = .one := by
  simp only [powNat, TA.powNat, TA.ofSingle, Nat.zero_ne_one, ↓reduceDIte]

/-- A typed Single to exponent one preserves its stored blade and coefficient. -/
@[simp] theorem powNat_one (s : Single V G α) : s.powNat 1 = TA.ofSingle s := by
  simp only [powNat, TA.ofSingle, TA.powNat, ↓reduceDIte]

/-- Exact scalar-Single refinement through the actual metric and term-power branches.
The scalar smart constructor supplies mask 0. The two computational witnesses establish
its basis square and One product; the only coefficient law is left identity. -/
theorem powNat_scalar (sq : TA.bladeSq V 0 = 1)
    (basis_mul : TA.mul (.one : TA V α) .one = .one)
    (left_id : ∀ x : α, Coeff.one * x = x) (x : α) (n : Nat) :
    (scalar (V := V) x).powNat n =
      if n = 0 then .one else .single 0 (TA.cpow x n) := by
  by_cases h1 : n = 1
  · subst n
    simp only [powNat_one, scalar, TA.ofSingle, Nat.one_ne_zero, ↓reduceIte,
      show TA.cpow x 1 = x from (TA.cpow_succ x 0).trans (left_id x)]
  by_cases h0 : n = 0
  · subst n
    simp only [powNat_zero, ↓reduceIte]
  · simp only [powNat, scalar, TA.ofSingle, TA.powNat, h1, h0, ↓reduceDIte,
      TA.powTerm, TA.ofBlade, sq, BEq.rfl, Bool.true_or, ↓reduceIte]
    simp only [Bool.false_eq_true, ↓reduceIte]
    split <;> simp only [basis_mul, TA.mulScalar]

/-- Scalar coefficients of the actual typed API are the executable coefficient powers,
including exponent zero. Assumptions are the scalar basis witnesses and left identity. -/
theorem powNat_scalar_coeff (sq : TA.bladeSq V 0 = 1)
    (basis_mul : TA.mul (.one : TA V α) .one = .one)
    (left_id : ∀ x : α, Coeff.one * x = x) (x : α) (n : Nat) :
    ((scalar (V := V) x).powNat n).coeff 0 = TA.cpow x n := by
  rw [powNat_scalar sq basis_mul left_id]
  by_cases h : n = 0
  · subst n
    rfl
  · simp only [h, ↓reduceIte, TA.coeff, BEq.rfl, TA.valid_zero, Bool.true_and]

/-- Addition of exponents at the actual scalar-Single API, via its coefficient refinement.
Only associative multiplication, left/right identities and the scalar basis witnesses;
this asserts no law for general geometric products or arbitrary raw grade-zero masks. -/
theorem powNat_scalar_coeff_add (sq : TA.bladeSq V 0 = 1)
    (basis_mul : TA.mul (.one : TA V α) .one = .one)
    (left_id : ∀ x : α, Coeff.one * x = x)
    (assoc : ∀ a b c : α, (a * b) * c = a * (b * c))
    (right_id : ∀ x : α, x * Coeff.one = x) (x : α) (m n : Nat) :
    ((scalar (V := V) x).powNat (m + n)).coeff 0 =
      ((scalar (V := V) x).powNat m).coeff 0 * ((scalar (V := V) x).powNat n).coeff 0 := by
  simp only [powNat_scalar_coeff sq basis_mul left_id]
  exact TA.cpow_add assoc right_id x m n

end Single

end Grassmann
