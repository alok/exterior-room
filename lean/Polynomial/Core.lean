/-
SPDX-License-Identifier: GPL-3.0-or-later
Adapted from FareyVision's canonical starscape-core.js, lattice.js and pair-plane.js
at ca809d2975a37a318a425e4b9dd73560b07faf39.
Modification: OpenAI Codex, 2026-10-23: exact Lean Int computations, bounded service,
and separate kernel-checked invariants. No original checkout is modified.
-/
import Lean

namespace Polynomial

structure Point where
  a : Int
  b : Int
  c : Int
  deriving Repr, BEq, DecidableEq, Inhabited

structure Vector where
  x : Int
  y : Int
  z : Int
  deriving Repr, BEq, DecidableEq

def Point.coords (p : Point) : Array Int := #[p.a, p.b, p.c]
def Vector.coords (v : Vector) : Array Int := #[v.x, v.y, v.z]
def Point.isZero (p : Point) : Bool := p.a == 0 && p.b == 0 && p.c == 0
def delta (p : Point) : Int := p.b*p.b - 4*p.a*p.c
def display (p : Point) : Vector := ⟨-p.b, p.a+p.c, p.c-p.a⟩
def normSquared (p : Point) : Int := p.b*p.b + 2*p.a*p.a + 2*p.c*p.c
def scale (k : Int) (p : Point) : Point := ⟨k*p.a, k*p.b, k*p.c⟩
def kindCode (p : Point) : Nat :=
  if delta p == 0 then 0 else if delta p > 0 then 1 else if p.a > 0 then 2 else 3
def kindName (p : Point) : String :=
  match kindCode p with | 0 => "null" | 1 => "exterior" | 2 => "upper" | _ => "lower"
def isUpper (p : Point) : Bool := p.a > 0 && delta p < 0
def positiveRepresentative (p : Point) : Option Point :=
  if delta p >= 0 then none else some (if p.a < 0 then scale (-1) p else p)
def divisor (p : Point) : Nat := Nat.gcd (Nat.gcd p.a.natAbs p.b.natAbs) p.c.natAbs
def primitive (p : Point) : Point :=
  let d : Int := divisor p
  let first := if p.a != 0 then p.a else if p.b != 0 then p.b else p.c
  let s : Int := if first < 0 then -1 else 1
  ⟨(p.a / d)*s, (p.b / d)*s, (p.c / d)*s⟩

def dual (p : Point) : Point := ⟨-2*p.c, p.b, -2*p.a⟩
def cross (p q : Point) : Point :=
  ⟨p.b*q.c-p.c*q.b, p.c*q.a-p.a*q.c, p.a*q.b-p.b*q.a⟩
def pairNormal (p q : Point) : Point := cross (dual p) (dual q)
def incidence (n p : Point) : Int := -2*n.c*p.a + n.b*p.b - 2*n.a*p.c
def planeNormal (n : Point) : Vector := ⟨-n.b, -n.a-n.c, n.c-n.a⟩
def dot (x y : Vector) : Int := x.x*y.x+x.y*y.y+x.z*y.z

def inBall (p : Point) (radius : Nat) : Bool :=
  !p.isZero && normSquared p <= (radius : Int)*(radius : Int)

/-- Exact a,c,b order used by the canonical packed browser lattice. -/
def cloud (radius : Nat) (upperOnly : Bool) : Array Point := Id.run do
  let mut result := #[]
  let r : Int := radius
  for ai in [:2*radius+1] do
    let a : Int := (ai : Int)-r
    for ci in [:2*radius+1] do
      let c : Int := (ci : Int)-r
      let rest := r*r - 2*a*a - 2*c*c
      if rest >= 0 then
        let m := rest.toNat.sqrt
        for bi in [:2*m+1] do
          let p : Point := ⟨a, (bi : Int)-(m : Int), c⟩
          if !p.isZero && (!upperOnly || isUpper p) then result := result.push p
  return result

def termsLabel (terms : Array (Int × String)) (separator : String := "") : String := Id.run do
  let mut result := ""
  for (coefficient, symbol) in terms do
    if coefficient != 0 then
      let magnitude := coefficient.natAbs
      let signText := if coefficient < 0 then "−" else if result.isEmpty then "" else "+"
      let number := if !symbol.isEmpty && magnitude == 1 then "" else toString magnitude
      result := result ++ (if result.isEmpty then "" else separator) ++ signText ++ number ++ symbol
  return if result.isEmpty then "0" else result

def polynomialLabel (p : Point) : String := termsLabel #[(p.a,"x²"),(p.b,"x"),(p.c,"")]
def equation (n : Point) : String := termsLabel #[(-2*n.c,"a"),(n.b,"b"),(-2*n.a,"c")] " " ++ " = 0"

structure Fraction where
  numerator : Int
  denominator : Nat
  deriving Repr

def fraction (p q : Int) : Fraction :=
  let d : Int := Nat.gcd p.natAbs q.natAbs
  let s : Int := if q < 0 then -1 else 1
  ⟨(p/d)*s, ((q/d)*s).toNat⟩

def Fraction.label (f : Fraction) : String :=
  if f.denominator == 1 then toString f.numerator else s!"{f.numerator}/{f.denominator}"

/-- Removes square factors using bounded integer trial division for endpoint labels. -/
def squareParts (n : Nat) : Nat × Nat := Id.run do
  let mut s := 1
  let mut r := n
  let mut f := 2
  while f*f <= r do
    while r % (f*f) == 0 do
      r := r/(f*f)
      s := s*f
    f := f+1
  return (s,r)

inductive Endpoint where
  | rational (f : Fraction)
  | surd (p : Int) (sign : Int) (s r q : Nat)
  | infinity
  deriving Repr

def makeSurd (p sign : Int) (d : Nat) (q : Int) : Endpoint :=
  let (s,r) := squareParts d
  let g : Int := Nat.gcd (Nat.gcd p.natAbs s) q.natAbs
  let qs : Int := if q < 0 then -1 else 1
  .surd ((p/g)*qs) sign (s/(g.toNat)) r (((q/g)*qs).toNat)

def Endpoint.label : Endpoint → String
  | .infinity => "∞"
  | .rational f => f.label
  | .surd p sign s r q =>
    let radical := (if s == 1 then "" else toString s) ++ "√" ++ toString r
    let head := if p == 0 then (if sign < 0 then "−" else "")
      else (toString p).replace "-" "−" ++ (if sign < 0 then " − " else " + ")
    if q == 1 then head ++ radical else "(" ++ head ++ radical ++ ")/" ++ toString q

def endpoints (n : Point) : Array Endpoint :=
  if n.a == 0 then #[.rational (fraction (-n.c) n.b), .infinity]
  else
    let d := (delta n).toNat
    let root := d.sqrt
    #[-1,1].map fun (sign : Int) =>
      if root*root == d then .rational (fraction (-n.b + sign*(root : Int)) (2*n.a))
      else makeSurd (-n.b) sign d (2*n.a)

end Polynomial
