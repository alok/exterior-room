// SPDX-License-Identifier: GPL-3.0-or-later
// Palette and glyph rules adapted from FareyVision ca809d2975a37a318a425e4b9dd73560b07faf39,
// Farey/Packages/FareyCore/Sources/FareyCore/CoefficientPalette.swift.
// Alok Singh with OpenAI Codex, 2026-10-23: read classifications from Lean responses.
import Foundation

/// Presentation of accepted Lean data. No discriminant, gcd or membership calculation lives here.
struct PolynomialPoint: Identifiable, Hashable, Sendable {
  let abc: [Int]
  let xyz: [Int]
  let delta: Int
  let kind: Int
  let divisor: Int
  let onPlane: Bool
  let necklace: Bool
  var id: String { abc.map(String.init).joined(separator: ":") }
  var vector: SIMD3<Float> { SIMD3(Float(xyz[0]), Float(xyz[1]), Float(xyz[2])) }
}

enum PolynomialAppearance {
  static func rgb(_ hex: Int) -> SIMD3<Double> {
    SIMD3(Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)) / 255
  }
  static let guide = rgb(0x54e9f5)
  static let guideLine = rgb(0x7896a8)
  static let selectionRay = rgb(0xbacbd6)
  static let amber = rgb(0xffba6b)

  static func color(_ point: PolynomialPoint, colorLower: Bool, palette: String = "viridis") -> SIMD3<Double> {
    let reference = palette == "reference"
    switch point.kind {
    case 0: return rgb(reference ? 0xd6bd69 : 0xf4f2ff)
    case 1: return rgb(reference ? 0x448abb : 0x7a5230)
    case 3 where !colorLower: return rgb(reference ? 0x64717d : 0x4d3a46)
    default:
      let t = min(1, max(0, log(Double(-point.delta) / 3) / log(240.0 / 3)))
      if reference { return referenceColor(t) }
      let table = PolynomialViridis.table
      let x = (0.2 + 0.8 * t) * Double(table.count - 1)
      let i = min(table.count - 2, Int(x.rounded(.down))), f = x - Double(i)
      return table[i] * (1 - f) + table[i + 1] * f
    }
  }

  // OKLab interpolation of Stange's six anchors, from pinned Farey/WebXR/appearance.js.
  private static let referenceAnchors = [0xf06a6a,0xe99456,0xd6bd69,0x7ab89b,0x70a6d8,0xad92d0].map { hex -> SIMD3<Double> in
    let rgb = rgb(hex)
    func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055,2.4) }
    let r = linear(rgb.x), g = linear(rgb.y), b = linear(rgb.z)
    let l = cbrt(0.4122214708*r+0.5363325363*g+0.0514459929*b)
    let m = cbrt(0.2119034982*r+0.6806995451*g+0.1073969566*b)
    let s = cbrt(0.0883024619*r+0.2817188376*g+0.6299787005*b)
    return [0.2104542553*l+0.793617785*m-0.0040720468*s,1.9779984951*l-2.428592205*m+0.4505937099*s,0.0259040371*l+0.7827717662*m-0.808675766*s]
  }
  static func referenceColor(_ t: Double) -> SIMD3<Double> {
    let x = min(1,max(0,t))*5, i = min(4,Int(x)), f = x-Double(i)
    let lab = referenceAnchors[i]*(1-f)+referenceAnchors[i+1]*f
    let l = pow(lab.x+0.3963377774*lab.y+0.2158037573*lab.z,3)
    let m = pow(lab.x-0.1055613458*lab.y-0.0638541728*lab.z,3)
    let s = pow(lab.x-0.0894841775*lab.y-1.291485548*lab.z,3)
    func gamma(_ value: Double) -> Double {
      let v = min(1,max(0,value))
      return min(1,max(0,v <= 0.0031308 ? 12.92*v : 1.055*pow(v,1/2.4)-0.055))
    }
    return [gamma(4.0767416621*l-3.3077115913*m+0.2309699292*s),gamma(-1.2684380046*l+2.6097574011*m-0.3413193965*s),gamma(-0.0041960863*l-0.7034186147*m+1.707614701*s)]
  }

  /// Approximate Euclidean distance in the transformed display coordinates. Exact membership comes from Lean.
  /// Position, normal and radius use the same coefficient-display units, before RealityKit's scene scale.
  static func focusFade(_ point: PolynomialPoint, position: SIMD3<Double>, normal: SIMD3<Double>, radius: Int, keep: [Int]) -> Double {
    guard point.abc != keep, !point.necklace else { return 1 }
    guard radius > 0, (0..<3).allSatisfy({ position[$0].isFinite && normal[$0].isFinite }) else { return 1 }
    let length = sqrt(normal.x*normal.x+normal.y*normal.y+normal.z*normal.z)
    guard length > 0, length.isFinite else { return 1 }
    let distance = abs(normal.x*position.x+normal.y*position.y+normal.z*position.z)/length
    let t = min(1,max(0,distance/(0.5*Double(radius))))
    return 1-0.88*t*t*(3-2*t)
  }

  static func radiusFactor(_ point: PolynomialPoint, colorLower: Bool, atOrigin: Bool) -> Float {
    guard point.delta < 0 else { return 1 }
    if atOrigin {
      return Float(0.4 * pow(Double(-point.delta), 0.25) / sqrt(Double(abs(point.xyz[1]))))
    }
    return (point.kind == 2 || colorLower) && point.divisor != 1 ? 0.72 : 1
  }

  static func linearLightOpacity(_ alpha: Double, color: SIMD3<Double>) -> Float {
    func linear(_ s: Double) -> Double { s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) }
    let c = max(color.x, color.y, color.z)
    return Float(c > 0 ? linear(alpha * c) / linear(c) : alpha)
  }
}
