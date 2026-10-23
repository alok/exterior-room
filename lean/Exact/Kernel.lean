import Grassmann.Examples.OrientedVolume

namespace Exact
open Grassmann DirectSum StaticVectors

/-- Exact integer coordinates; each coordinate represents a quarter world unit. -/
structure Vec3 where
  x : Int
  y : Int
  z : Int
  deriving Repr, BEq

def Vec3.toList (v : Vec3) : List Int := [v.x, v.y, v.z]

def Vec3.add (a b : Vec3) : Vec3 := ⟨a.x + b.x, a.y + b.y, a.z + b.z⟩

def Vec3.toChain (v : Vec3) : Chain ℝ3 1 Int :=
  ⟨Values.ofFn fun i => match i.val with | 0 => v.x | 1 => v.y | _ => v.z⟩

/-- Actual Grassmann generated provider, frozen to the provider in the imported proofs. -/
def wedge (a b : Vec3) : TA ℝ3 Int :=
  @TA.wedgeF ℝ3 Int _ Kernel.Gen.ℝ3.instKernels instDynKernelsℝ3
    (.chain 1 a.toChain) (.chain 1 b.toChain)

/-- Packed exterior basis [e12,e13,e23], observed from the actual result. -/
def wedgeCoordinates (a b : Vec3) : List Int :=
  let result := wedge a b
  [result.coeff 3, result.coeff 5, result.coeff 6]

/-- Reuse the upstream consumer's proven generated two-stage wedge entrypoint. -/
def volume (a b c : Vec3) : Int :=
  Grassmann.Examples.OrientedVolume.coefficient a.toChain b.toChain c.toChain

def vertices (a b c : Vec3) : List (List Int) :=
  [Vec3.toList ⟨0,0,0⟩, a.toList, b.toList, c.toList,
    (a.add b).toList, (a.add c).toList, (b.add c).toList, ((a.add b).add c).toList]

end Exact
