import Polynomial.Core
import Polynomial.Transform
import Polynomial.Catalogue
import Lean.Data.Json

open Lean
namespace Polynomial.Service

def sourceCommit : String := "ca809d2975a37a318a425e4b9dd73560b07faf39"
def actionSourceCommit : String := "63ad115422ab1141ca6d06732572385414b7a5cf"
-- Exact identities can leave the finite R96 cloud after integral absorption.
-- With matrix entries bounded by 10^6, exported numerators stay below 2^53.
def identityBound : Int := 1024
-- The raw dual-cross pair normal is divisible by two; primitive coordinates are ≤4B².
def normalBound : Int := 4*identityBound*identityBound

def common (id : Json) (ok : Bool) : Json := json%{
  id: $id, ok: $ok, schema: "polynomial-space-v1",
  engine: "Lean 4.35.0-rc3", sourceCommit: $sourceCommit
}

def fail (id : Json) (message : String) : Json :=
  (common id false).mergeObj (json%{error: $message})

def readNat (request : Json) (key : String) (lo hi : Nat) (fallback : Option Nat := none) :
    Except String Nat := do
  let n ← match request.getObjVal? key with
    | .ok j => j.getNat?
    | .error _ => match fallback with | some n => pure n | none => throw s!"Missing {key}."
  if n < lo || n > hi then throw s!"{key} must be an integer from {lo} to {hi}."
  return n

def readBool (request : Json) (key : String) (fallback : Bool) : Except String Bool :=
  match request.getObjVal? key with
  | .ok j => j.getBool?
  | .error _ => pure fallback

def readPointValue (value : Json) (bound : Int) : Except String Point := do
  let values ← value.getArr?.mapError (fun _ => "Use integer coefficient triples.")
  if values.size != 3 then throw "Use integer coefficient triples."
  let a ← values[0]!.getInt?.mapError (fun _ => "Use integer coefficient triples.")
  let b ← values[1]!.getInt?.mapError (fun _ => "Use integer coefficient triples.")
  let c ← values[2]!.getInt?.mapError (fun _ => "Use integer coefficient triples.")
  if [a,b,c].any (fun n => n < -bound || n > bound) then
    throw s!"Coefficient magnitude must not exceed {bound}."
  return ⟨a,b,c⟩

def readPoint (request : Json) (key : String) (bound : Int := identityBound) : Except String Point := do
  readPointValue (← request.getObjVal? key) bound

def readNormal (request : Json) : Except String Point := do
  let n ← readPoint request "normal" normalBound
  if n.isZero then throw "The zero triple has no plane."
  return n

def fractionJson (f : Fraction) : Json := toJson #[f.numerator, (f.denominator : Int)]

def readMatrix (request : Json) : Except String Mobius.Matrix := do
  let values ← (← request.getObjVal? "matrix").getArr?
  if values.size != 4 then throw "Use four integer matrix entries."
  let entries ← values.mapM fun value => value.getInt?
  if entries.any (fun value => value < -1000000 || value > 1000000) then
    throw "Matrix entries must be integers from -1000000 to 1000000."
  return ⟨entries[0]!,entries[1]!,entries[2]!,entries[3]!⟩

def transform (request : Json) : Except String Json := do
  let g ← readMatrix request
  let d := Mobius.determinant g
  if d <= 0 then throw "The matrix determinant must be positive."
  let p ← readPoint request "point"
  if p.isZero then throw "The zero polynomial is not a point of this lattice."
  let moved := Mobius.apply g p
  let preserved := delta moved == d*d*delta p
  if !preserved then throw "Internal exact discriminant check failed."
  let integral := moved.coords.all fun n => n % d == 0
  let image : Option (Array Int) := if integral then some (moved.coords.map (· / d)) else none
  return json%{actionSchema: "polynomial-mobius-v1", actionSourceCommit: $actionSourceCommit,
    matrix: $(g.coords), denominator: $d, coefficientRows: $(Mobius.rows g),
    point: $(p.coords), imageNumerator: $(moved.coords), xyzNumerator: $((display moved).coords),
    delta: $(delta p), image: $image,
    checks: {positiveDeterminant: true, discriminantPreserved: $preserved}}

def inspect (request : Json) : Except String Json := do
  let p ← readPoint request "point"
  if p.isZero then throw "The zero polynomial is not a point of this lattice."
  let h ← readNat request "height" 1 24 (some 4)
  let representative := positiveRepresentative p
  let projection := match representative with
    | none => Json.null
    | some q => Json.arr ((display q).coords.map fun v => fractionJson (fraction (v*(h : Int)) (q.a+q.c)))
  let root := match representative with
    | none => Json.null
    | some q => json%{real: $(fractionJson (fraction (-q.b) (2*q.a))),
        imaginary: {radicand: $(-delta q), denominator: $(2*q.a)}}
  return json%{point: $(p.coords), polynomial: $(polynomialLabel p), delta: $(delta p),
    kind: $(kindName p), xyz: $((display p).coords), divisor: $(divisor p),
    primitive: $((primitive p).coords),
    positiveRepresentative: $(representative.map Point.coords),
    height: $h, projection: $projection, root: $root}

def endpointJson (e : Endpoint) : Json :=
  match e with
  | .infinity => json%{kind: "infinity", label: $(e.label)}
  | .rational f => json%{kind: "rational", numerator: $(f.numerator),
      denominator: $(f.denominator), label: $(e.label)}
  | .surd p sign s r q => json%{kind: "surd", p: $p, sign: $sign,
      s: $s, r: $r, q: $q, label: $(e.label)}

def planeFrom (raw : Point) : Except String Json := do
  if raw.isZero then throw "The zero triple has no plane."
  let n := primitive raw
  if delta n <= 0 then throw "These directions do not define a real geodesic."
  -- Keep pair outputs within the same normal domain accepted by membership requests.
  if n.coords.any (fun value => value < -normalBound || value > normalBound) then
    throw "This pair normal exceeds the bounded plane service."
  -- Keep trial division for canonical surd labels finite and inexpensive.
  if (delta n).natAbs > 1000000000000 then throw "This plane is too large for the bounded endpoint service."
  return json%{normal: $(n.coords), planeCoefficients: $((dual n).coords),
    cartesianNormal: $((planeNormal n).coords), equation: $(equation n),
    endpoints: $((endpoints n).map endpointJson),
    checks: {exterior: $(decide (delta n > 0)), primitive: $(divisor n == 1)}}

def plane (request : Json) : Except String Json := do
  planeFrom (← readNormal request)

def pair (request : Json) : Except String Json := do
  let first ← readPoint request "first"
  let second ← readPoint request "second"
  if delta first >= 0 || delta second >= 0 then
    throw "Pair two complex-root points inside the cone (Δ < 0)."
  let raw := pairNormal first second
  if raw.isZero then
    throw "These triples have the same primitive direction and root. Choose a different root."
  let result ← planeFrom raw
  let n := primitive raw
  if incidence n first != 0 || incidence n second != 0 then
    throw "Internal exact plane normalization check failed."
  let checks := (result.getObjValD "checks").mergeObj
    (json%{firstOnPlane: true, secondOnPlane: true,
      rawFirstOnPlane: $(incidence raw first == 0), rawSecondOnPlane: $(incidence raw second == 0)})
  return result.mergeObj (json%{firstPrimitive: $((primitive first).coords),
    secondPrimitive: $((primitive second).coords), checks: $checks})

structure Cache where
  radius : Nat
  upperOnly : Bool
  points : Array Point

def cached (state : Option Cache) (radius : Nat) (upperOnly : Bool) : Cache :=
  match state with
  | some cache =>
    if cache.radius == radius && cache.upperOnly == upperOnly then cache
    else ⟨radius, upperOnly, Polynomial.cloud radius upperOnly⟩
  | none => ⟨radius, upperOnly, Polynomial.cloud radius upperOnly⟩

def cloudPage (request : Json) (state : Option Cache) : Except String (Json × Option Cache) := do
  let radius ← readNat request "radius" 4 96
  let upperOnly ← readBool request "upperOnly" false
  let offset ← readNat request "offset" 0 2000000 (some 0)
  let limit ← readNat request "limit" 1 16384 (some 16384)
  let normal ← match request.getObjVal? "normal" with
    | .ok _ => some <$> readNormal request
    | .error _ => pure none
  let cache := cached state radius upperOnly
  let total := cache.points.size
  let endIndex := min total (offset+limit)
  let count := endIndex-offset
  let mut abc : Array Int := Array.mkEmpty (3*count)
  let mut xyz : Array Int := Array.mkEmpty (3*count)
  let mut deltas : Array Int := Array.mkEmpty count
  let mut kinds : Array Nat := Array.mkEmpty count
  let mut divisors : Array Nat := Array.mkEmpty count
  let mut onPlane : Array Bool := Array.mkEmpty count
  let mut necklace : Array Bool := Array.mkEmpty count
  for i in [offset:endIndex] do
    let p := cache.points[i]!
    abc := abc.push p.a |>.push p.b |>.push p.c
    let v := display p
    xyz := xyz.push v.x |>.push v.y |>.push v.z
    let d := delta p
    deltas := deltas.push d
    kinds := kinds.push (kindCode p)
    divisors := divisors.push (divisor p)
    if let some n := normal then
      let member := incidence n p == 0
      onPlane := onPlane.push member
      necklace := necklace.push (member && d < 0)
  let nextOffset : Option Nat := if endIndex < total then some endIndex else none
  let onPlaneJson := if normal.isSome then toJson onPlane else Json.null
  let necklaceJson := if normal.isSome then toJson necklace else Json.null
  return (json%{radius: $radius, upperOnly: $upperOnly, offset: $offset,
    count: $count, total: $total, nextOffset: $nextOffset, abc: $abc, xyz: $xyz,
    delta: $deltas, kind: $kinds, divisor: $divisors,
    onPlane: $onPlaneJson, necklace: $necklaceJson}, some cache)

def members (request : Json) (state : Option Cache) : Except String (Json × Option Cache) := do
  let radius ← readNat request "radius" 4 96
  let upperOnly ← readBool request "upperOnly" false
  let normal ← readNormal request
  let cache := cached state radius upperOnly
  let mut indices : Array Nat := #[]
  for i in [:cache.points.size] do
    let p := cache.points[i]!
    if delta p < 0 && incidence normal p == 0 then indices := indices.push i
  return (json%{radius: $radius, upperOnly: $upperOnly,
    total: $(cache.points.size), count: $(indices.size), indices: $indices}, some cache)

structure State where
  cloud : Option Cache := none
  catalogue : Option Catalogue.Result := none

def readCatalogueConfig (request : Json) : Except String Catalogue.Config := do
  let depth ← readNat request "depth" 4 96
  let matrix ← readMatrix request
  if Mobius.determinant matrix <= 0 then throw "The catalogue matrix determinant must be positive."
  let whole ← readBool request "whole" true
  let dust ← readBool request "dust" false
  return ⟨depth,matrix,whole,dust⟩

def cachedCatalogue (request : Json) (state : State) : Except String Catalogue.Result := do
  let config ← readCatalogueConfig request
  if let some old := state.catalogue then
    if old.config == config then return old
  Catalogue.build config

def catalogueMetadata (result : Catalogue.Result) : Json :=
  let c := result.config
  json%{catalogueSchema: $(Catalogue.schema), catalogueSourceSHA256: $(Catalogue.sourceSHA256),
    cacheKey: $(c.key), depth: $(c.depth), matrix: $(c.matrix.coords), whole: $(c.whole),
    dust: $(c.dust), otherRadius: $(c.otherRadius), padding: $((#[6,5] : Array Nat)),
    denominator: $(Mobius.determinant c.matrix), coefficientRows: $(Mobius.rows c.matrix),
    upperCount: $(result.upperCount), otherCount: $(result.otherCount), total: $(result.points.size),
    complete: $(result.complete),
    sourceLimited: {upperCap: $(result.upperCap), otherScanBound: $(result.otherOmitted)},
    otherScanBound: $(result.otherScanBound)}

def cataloguePage (request : Json) (state : State) : Except String (Json × State) := do
  let offset ← readNat request "offset" 0 2000000 (some 0)
  let limit ← readNat request "limit" 1 16384 (some 16384)
  let result ← cachedCatalogue request state
  let endIndex := min result.points.size (offset+limit)
  let count := endIndex-offset
  let mut abc : Array Int := Array.mkEmpty (3*count)
  let mut xyz : Array Int := Array.mkEmpty (3*count)
  let mut deltas : Array Int := Array.mkEmpty count
  let mut kinds : Array Nat := Array.mkEmpty count
  let mut divisors : Array Nat := Array.mkEmpty count
  let mut primitives : Array Bool := Array.mkEmpty count
  for i in [offset:endIndex] do
    let p := result.points[i]!
    abc := abc ++ p.coords
    xyz := xyz ++ (display p).coords
    deltas := deltas.push (delta p)
    kinds := kinds.push (kindCode p)
    let divisor := Polynomial.divisor p
    divisors := divisors.push divisor
    primitives := primitives.push (divisor == 1)
  let nextOffset : Option Nat := if endIndex < result.points.size then some endIndex else none
  let page := json%{offset: $offset, count: $count, nextOffset: $nextOffset,
    abc: $abc, xyz: $xyz, delta: $deltas, kind: $kinds, divisor: $divisors,
    primitive: $primitives, onPlane: null, necklace: null}
  return ((catalogueMetadata result).mergeObj page, {state with catalogue := some result})

def catalogueMembers (request : Json) (state : State) : Except String (Json × State) := do
  let normal ← readNormal request
  let result ← cachedCatalogue request state
  let mut indices : Array Nat := #[]
  for i in [:result.points.size] do
    let point := result.points[i]!
    if delta point < 0 && incidence normal point == 0 then indices := indices.push i
  let membership := json%{normal: $(normal.coords), count: $(indices.size), indices: $indices}
  return ((catalogueMetadata result).mergeObj membership, {state with catalogue := some result})

def respond (request : Json) (state : State) : Except String (Json × State) := do
  let op ← (← request.getObjVal? "op").getStr?
  match op with
  | "cloud" =>
    let (payload,cache) ← cloudPage request state.cloud
    return (payload,{state with cloud := cache})
  | "members" =>
    let (payload,cache) ← members request state.cloud
    return (payload,{state with cloud := cache})
  | "catalogue" => cataloguePage request state
  | "membersCatalogue" => catalogueMembers request state
  | "inspect" => return (← inspect request, state)
  | "plane" => return (← plane request, state)
  | "pair" => return (← pair request, state)
  | "transform" => return (← transform request, state)
  | _ => throw "Unknown operation; use cloud, members, catalogue, membersCatalogue, inspect, plane, pair, or transform."

def process (line : String) (state : State) : Json × State :=
  match Json.parse line with
  | .error message => (fail Json.null message, state)
  | .ok request =>
    let id := request.getObjValD "id"
    match respond request state with
    | .error message => (fail id message, state)
    | .ok (payload, nextState) => ((common id true).mergeObj payload, nextState)

end Polynomial.Service

def main : IO Unit := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  let mut state : Polynomial.Service.State := {}
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    let (response,nextState) := Polynomial.Service.process line state
    state := nextState
    output.putStrLn response.compress
    output.flush
