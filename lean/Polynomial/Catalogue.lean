/-
SPDX-License-Identifier: GPL-3.0-or-later
Exact-integer implementation of the original Starscape catalogue predicates.
Source behavior audit: docs/source-recrop-audit.md; deployed script SHA-256
f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b.
This module does not copy the deployed implementation. Its integer bounds are
derived in that audit. Source caps are explicit; local budget failures are errors.
-/
import Polynomial.Transform

namespace Polynomial.Catalogue

def schema : String := "source-catalogue-v1"
def sourceSHA256 : String := "f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b"
def identityBound : Int := 1024
def upperLimit : Nat := 600000
def outputLimit : Nat := 2000000
def upperColumnLimit : Nat := 2000000
def candidateLimit : Nat := 4000000

structure Config where
  depth : Nat
  matrix : Mobius.Matrix
  whole : Bool
  dust : Bool
  deriving BEq

def Config.otherRadius (c : Config) : Nat :=
  if c.whole then (2*c.depth+2)/5 else if c.dust then 10 else 0

def Config.key (c : Config) : String :=
  let m := String.intercalate "," (c.matrix.coords.toList.map toString)
  let w : Nat := if c.whole then 1 else 0
  let d : Nat := if c.dust then 1 else 0
  s!"{schema}:{c.depth}:{m}:{w}:{d}"

structure Result where
  config : Config
  points : Array Point
  upperCount : Nat
  upperCap : Bool
  otherScanBound : Nat
  otherOmitted : Bool
  candidates : Nat

def Result.otherCount (r : Result) : Nat := r.points.size-r.upperCount
def Result.complete (r : Result) : Bool := !r.upperCap && !r.otherOmitted

/-- Exact floor of the inverse-display Frobenius enclosure times padded radius. -/
def otherBound (config : Config) : Nat :=
  let rows := Mobius.rows (Mobius.adjugate config.matrix)
  let n := (#[0,3,6] : Array Nat).foldl (fun total i =>
    total+rows[i]!*rows[i]!+2*rows[i+1]!*rows[i+1]!+rows[i+2]!*rows[i+2]!) (0 : Int)
  let d := Mobius.determinant config.matrix
  let radius : Int := config.otherRadius
  ((36*radius*radius*n)/(50*d*d)).toNat.sqrt

def upper (config : Config) : Except String (Array Point × Bool × Nat) := do
  let matrix := config.matrix
  let determinant := Mobius.determinant matrix
  if determinant <= 0 then throw "The catalogue matrix determinant must be positive."
  let alpha := 5*(matrix.s*matrix.s+matrix.q*matrix.q)
  let beta := 5*(-matrix.r*matrix.s-matrix.p*matrix.q)
  let gamma := 5*(matrix.r*matrix.r+matrix.p*matrix.p)
  let height : Int := 6*(config.depth : Int)*determinant
  let discriminant := alpha*gamma-beta*beta
  let aMax := (gamma*height-1)/discriminant
  let cMax := (alpha*height-1)/discriminant
  -- Conservative full-cone envelopes are checked before any enumeration.
  if aMax > identityBound || cMax > identityBound then
    throw "Catalogue identity envelope exceeds 1024; reduce depth or action strength."
  let mut points := #[]
  let mut columns := 0
  for ai in [1:aMax.toNat+1] do
    let a : Int := ai
    let extent := 4*a*(gamma*height-a*discriminant)
    if extent > 0 then
      let bound : Int := (extent-1).toNat.sqrt
      let bMin := -((bound+2*a*beta)/gamma)
      let bMax := (bound-2*a*beta)/gamma
      let count := (bMax-bMin+1).toNat
      if columns+count > upperColumnLimit then
        throw "Catalogue upper-column budget exceeded; reduce depth or action strength."
      columns := columns+count
      for bi in [:count] do
        let b := bMin+(bi : Int)
        let cMin := b*b/(4*a)+1
        let cMax := (height-alpha*a-beta*b)/gamma
        for ci in [:(cMax-cMin+1).toNat] do
          let c := cMin+(ci : Int)
          if b < -identityBound || b > identityBound || c > identityBound then
            throw "Catalogue point exceeds the 1024 identity bound."
          points := points.push ⟨a,b,c⟩
          -- Matching the source's stop-at-cap behavior conservatively marks
          -- the result incomplete, even if the last point happens to be last.
          if points.size >= upperLimit then return (points,true,columns)
  return (points,false,columns)

def build (config : Config) : Except String Result := do
  let (upperPoints,upperCap,columns) ← upper config
  let radius := config.otherRadius
  let bound := if radius == 0 then 0 else otherBound config
  let omitted := radius > 0 && bound > 64
  let mut points := upperPoints
  let mut candidates := columns
  if radius > 0 && !omitted then
    let width := 2*bound+1
    let scanCount := width*width*width
    if candidates+scanCount > candidateLimit then
      throw "Catalogue candidate budget exceeded; reduce depth or action strength."
    candidates := candidates+scanCount
    let d := Mobius.determinant config.matrix
    let radius : Int := radius
    let maximum := 36*radius*radius*d*d
    for ai in [:width] do
      let a := (ai : Int)-(bound : Int)
      for bi in [:width] do
        let b := (bi : Int)-(bound : Int)
        for ci in [:width] do
          let c := (ci : Int)-(bound : Int)
          let point : Point := ⟨a,b,c⟩
          if !point.isZero && !isUpper point then
            let moved := Mobius.apply config.matrix point
            if 25*normSquared moved <= maximum then
              if points.size >= outputLimit then
                throw "Catalogue output budget exceeded; reduce depth."
              points := points.push point
  return ⟨config,points,upperPoints.size,upperCap,bound,omitted,candidates⟩

end Polynomial.Catalogue
