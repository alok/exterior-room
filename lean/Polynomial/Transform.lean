/-
SPDX-License-Identifier: GPL-3.0-or-later
Coefficient pushforward convention from FareyVision WebXR/mobius.js,
commit 63ad115422ab1141ca6d06732572385414b7a5cf.
Exact integer numerator implementation; no continuous pointer arithmetic is performed here.
-/
import Polynomial.Core

namespace Polynomial.Mobius

structure Matrix where
  p : Int
  q : Int
  r : Int
  s : Int
  deriving Repr, BEq, DecidableEq

def Matrix.coords (g : Matrix) : Array Int := #[g.p, g.q, g.r, g.s]
def determinant (g : Matrix) : Int := g.p*g.s-g.q*g.r
def identity : Matrix := ⟨1,0,0,1⟩
def multiply (g h : Matrix) : Matrix :=
  ⟨g.p*h.p+g.q*h.r, g.p*h.q+g.q*h.s,
   g.r*h.p+g.s*h.r, g.r*h.q+g.s*h.s⟩
def adjugate (g : Matrix) : Matrix := ⟨g.s,-g.q,-g.r,g.p⟩

/-- Numerator of Q ∘ (M/√det M)⁻¹; its denominator is det M > 0. -/
def apply (g : Matrix) (v : Point) : Point :=
  ⟨g.s*g.s*v.a-g.r*g.s*v.b+g.r*g.r*v.c,
   -2*g.q*g.s*v.a+(g.p*g.s+g.q*g.r)*v.b-2*g.p*g.r*v.c,
   g.q*g.q*v.a-g.p*g.q*v.b+g.p*g.p*v.c⟩

/-- Row-major integer numerator matrix J(M); divide every entry by det M. -/
def rows (g : Matrix) : Array Int :=
  #[g.s*g.s, -g.r*g.s, g.r*g.r,
    -2*g.q*g.s, g.p*g.s+g.q*g.r, -2*g.p*g.r,
    g.q*g.q, -g.p*g.q, g.p*g.p]

/-- The row-major layout returned by the service, evaluated as a matrix action. -/
def rowsApply (g : Matrix) (v : Point) : Point :=
  let m := rows g
  ⟨m[0]!*v.a+m[1]!*v.b+m[2]!*v.c,
   m[3]!*v.a+m[4]!*v.b+m[5]!*v.c,
   m[6]!*v.a+m[7]!*v.b+m[8]!*v.c⟩

end Polynomial.Mobius
