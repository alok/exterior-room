import Exact.Kernel
import Lean.Data.Json

open Lean Exact

def parseCoordinate (value : Json) : Except String Int := do
  let n ← value.getInt?
  if n < -12 || n > 12 then
    throw "Coordinates must be integers between -12 and 12."
  return n

def parseVector (request : Json) (name : String) : Except String Vec3 := do
  let values ← (← request.getObjVal? name).getArr?
  if values.size != 3 then throw s!"{name} must contain exactly three integers."
  return ⟨← parseCoordinate values[0]!, ← parseCoordinate values[1]!,
    ← parseCoordinate values[2]!⟩

def respond (request : Json) : Except String Json := do
  let a ← parseVector request "a"
  let b ← parseVector request "b"
  let c ← parseVector request "c"
  let id := request.getObjValD "id"
  let w := wedgeCoordinates a b
  let swapped := wedgeCoordinates b a
  let self := wedgeCoordinates a a
  let vol := volume a b c
  let swappedVol := volume b a c
  let repeatedVol := volume a a c
  return json%{
    ok: true, id: $id, a: $(a.toList), b: $(b.toList), c: $(c.toList), scale: 4,
    wedge: $w, swappedWedge: $swapped, selfWedge: $self,
    volume: $vol, swappedVolume: $swappedVol, repeatedVolume: $repeatedVol,
    vertices: $(vertices a b c),
    checks: {antisymmetric: $(swapped == w.map (fun n => -n)),
      selfZero: $(self == [0,0,0]),
      volumeAntisymmetric: $(swappedVol == -vol), repeatedVolumeZero: $(repeatedVol == 0)},
    engine: "Grassmann/Lean 4.35.0-rc3",
    sourceCommit: "87e12dcfac41a0703bd0192f5e5a9b5e4c82d610"
  }

def processLine (line : String) : Json :=
  match Json.parse line with
  | .error error => json%{ok: false, id: null, error: $error}
  | .ok request =>
    match respond request with
    | .ok response => response
    | .error error => json%{ok: false, id: $(request.getObjValD "id"), error: $error}

def main : IO Unit := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    output.putStrLn (processLine line).compress
    output.flush
