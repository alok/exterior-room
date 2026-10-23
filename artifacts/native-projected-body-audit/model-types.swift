// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Exact data comes from polynomial_service.
import Foundation
import Observation

struct PolynomialHeader: Decodable {
  let ok: Bool
  let id: Int
  let schema: String
  let engine: String
  let sourceCommit: String
  let error: String?
  var recognized: Bool {
    schema == "polynomial-space-v1" && engine == "Lean 4.35.0-rc3"
      && sourceCommit == "ca809d2975a37a318a425e4b9dd73560b07faf39"
  }
}

struct PolynomialCloud: Decodable {
  let radius: Int, offset: Int, count: Int, total: Int
  let upperOnly: Bool
  let nextOffset: Int?
  let abc: [Int], xyz: [Int], delta: [Int], kind: [Int], divisor: [Int]
  var isValid: Bool {
    guard (4...96).contains(radius), count >= 0, count <= 16384, (0...2_000_000).contains(offset),
      total >= offset + count, total <= 2_000_000,
      abc.count == count * 3, xyz.count == count * 3,
      [delta.count, kind.count, divisor.count].allSatisfy({ $0 == count }),
      abc.allSatisfy({ (-96...96).contains($0) }), xyz.allSatisfy({ (-192...192).contains($0) }),
      delta.allSatisfy({ (-46_080...46_080).contains($0) }),
      kind.allSatisfy({ (0...3).contains($0) }), divisor.allSatisfy({ (1...96).contains($0) }),
      nextOffset == (offset + count < total ? offset + count : nil)
    else { return false }
    for i in 0..<count {
      let j = i * 3, a = abc[j], b = abc[j+1], c = abc[j+2]
      guard a != 0 || b != 0 || c != 0,
        Array(xyz[j..<(j+3)]) == [-b, a+c, c-a],
        (kind[i] == 0 ? delta[i] == 0 : kind[i] == 1 ? delta[i] > 0 : delta[i] < 0),
        kind[i] != 2 || a > 0, kind[i] != 3 || a < 0,
        delta[i] >= 0 || xyz[j+1] != 0
      else { return false }
    }
    return true
  }
  var points: [PolynomialPoint] {
    (0..<count).map { i in
      let j = i * 3
      return PolynomialPoint(abc: Array(abc[j..<(j+3)]), xyz: Array(xyz[j..<(j+3)]),
        delta: delta[i], kind: kind[i], divisor: divisor[i], onPlane: false, necklace: false)
    }
  }
}

struct PolynomialInspection: Decodable {
  struct Root: Decodable {
    struct Imaginary: Decodable { let radicand: Int, denominator: Int }
    let real: [Int]
    let imaginary: Imaginary
  }
  let point: [Int], xyz: [Int], primitive: [Int]
  let polynomial: String, kind: String
  let delta: Int, divisor: Int
  let positiveRepresentative: [Int]?
  let projection: [[Int]]?
  let root: Root?
  var displayPolynomial: String { PolynomialLabels.spaced(polynomial) }
  var isValid: Bool {
    let bound = PolynomialIdentityBounds.coordinate
    guard point.count == 3, point.allSatisfy({ (-bound...bound).contains($0) }), point != [0,0,0],
      xyz == [-point[1], point[0]+point[2], point[2]-point[0]],
      primitive.count == 3, primitive.allSatisfy({ (-bound...bound).contains($0) }),
      (1...bound).contains(divisor), (-PolynomialIdentityBounds.delta...PolynomialIdentityBounds.delta).contains(delta),
      ["null", "exterior", "upper", "lower"].contains(kind), !polynomial.isEmpty,
      (kind == "null" ? delta == 0 : kind == "exterior" ? delta > 0 : delta < 0),
      kind != "upper" || point[0] > 0, kind != "lower" || point[0] < 0
    else { return false }
    let sign = (point.first(where: { $0 != 0 }) ?? 1) < 0 ? -1 : 1
    guard point.allSatisfy({ $0 % divisor == 0 }), primitive == point.map({ $0 / divisor * sign }) else { return false }
    if delta < 0 {
      guard positiveRepresentative == point.map({ $0 * (point[0] < 0 ? -1 : 1) }), projection != nil, root != nil else { return false }
    } else if positiveRepresentative != nil || root != nil { return false }
    if let projection, !(projection.count == 3 && projection.allSatisfy({
      $0.count == 2 && (-48*bound...48*bound).contains($0[0]) && (1...2*bound).contains($0[1])
    })) { return false }
    if let root, !(root.real.count == 2 && (-bound...bound).contains(root.real[0]) && (1...2*bound).contains(root.real[1])
      && (1...4*bound*bound).contains(root.imaginary.radicand) && (1...2*bound).contains(root.imaginary.denominator)) { return false }
    return true
  }
  var rootText: String {
    guard let root else { return kind == "exterior" ? "Two real projective roots" : "Boundary of the cone" }
    return "\(root.real[0])/\(root.real[1]) + i√\(root.imaginary.radicand)/\(root.imaginary.denominator)"
  }
}

/// Typography only: keep the exact signed Lean label untouched in transport and model data.
enum PolynomialLabels {
  static func spaced(_ raw: String) -> String {
    let characters = raw.filter { !$0.isWhitespace }
    return characters.enumerated().map { index, character in
      index > 0 && (character == "+" || character == "−" || character == "-")
        ? " \(character) " : String(character)
    }.joined()
  }
}

struct PolynomialPlane: Decodable {
  struct Endpoint: Decodable {
    let kind: String, label: String
    let numerator: Int?, denominator: Int?
    let p: Int?, sign: Int?, s: Int?, r: Int?, q: Int?
    var isValid: Bool {
      switch kind {
      case "infinity": return true
      case "rational": return numerator != nil && (denominator ?? 0) > 0
      case "surd": return p != nil && [1,-1].contains(sign ?? 0) && (s ?? 0) > 0 && (r ?? 0) > 1 && (q ?? 0) > 0
      default: return false
      }
    }
    /// Approximate display conversion only; the label remains the exact Lean descriptor.
    var displayValue: Double {
      switch kind {
      case "infinity": return .infinity
      case "rational": return Double(numerator!) / Double(denominator!)
      default: return (Double(p!) + Double(sign!) * Double(s!) * sqrt(Double(r!))) / Double(q!)
      }
    }
  }
  let normal: [Int], planeCoefficients: [Int], cartesianNormal: [Int]
  let equation: String, endpoints: [Endpoint], checks: [String: Bool]
  var isValid: Bool {
    guard normal.count == 3, normal.allSatisfy({ (-PolynomialIdentityBounds.normal...PolynomialIdentityBounds.normal).contains($0) }),
      normal != [0,0,0], endpoints.count == 2, endpoints.allSatisfy(\.isValid),
      checks["exterior"] == true, checks["primitive"] == true,
      checks.values.allSatisfy({ $0 }), !equation.isEmpty
    else { return false }
    return planeCoefficients == [-2*normal[2], normal[1], -2*normal[0]]
      && cartesianNormal == [-normal[1], -normal[0]-normal[2], normal[2]-normal[0]]
  }
  var isValidPair: Bool {
    isValid && ["firstOnPlane","secondOnPlane","rawFirstOnPlane","rawSecondOnPlane"].allSatisfy { checks[$0] == true }
  }
}

private struct PolynomialMembers: Decodable {
  let radius: Int, total: Int, count: Int
  let upperOnly: Bool, indices: [Int]
}

