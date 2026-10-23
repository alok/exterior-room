// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23.
// Transport validation for Polynomial/Catalogue.lean, source-catalogue-v1.
// Source behavior SHA-256: f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b.
// These consistency checks neither enumerate a catalogue nor replace a Lean response.
import Foundation

struct PolynomialCatalogueMetadata: Decodable, Equatable, Sendable {
  struct SourceLimited: Decodable, Equatable, Sendable {
    let upperCap: Bool
    let otherScanBound: Bool
  }

  static let sourceSHA256 = "f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b"
  static let maximumTotal = 2_000_000
  let ok: Bool, id: Int
  let schema: String, engine: String, sourceCommit: String
  let catalogueSchema: String, catalogueSourceSHA256: String, cacheKey: String
  let depth: Int, matrix: [Int], whole: Bool, dust: Bool
  let otherRadius: Int, padding: [Int]
  let denominator: Int, coefficientRows: [Int]
  let upperCount: Int, otherCount: Int, total: Int
  let complete: Bool, sourceLimited: SourceLimited, otherScanBound: Int

  var isValid: Bool {
    guard ok, (0...9_007_199_254_740_991).contains(id),
      schema == "polynomial-space-v1", engine == "Lean 4.35.0-rc3",
      sourceCommit == "ca809d2975a37a318a425e4b9dd73560b07faf39",
      catalogueSchema == "source-catalogue-v1", catalogueSourceSHA256 == Self.sourceSHA256,
      (4...96).contains(depth), matrix.count == 4,
      matrix.allSatisfy({ (-1_000_000...1_000_000).contains($0) }),
      (1...2_000_000_000_000).contains(denominator), coefficientRows.count == 9,
      coefficientRows.allSatisfy({ (-2_000_000_000_000...2_000_000_000_000).contains($0) }),
      (0...600_000).contains(upperCount), (0...Self.maximumTotal).contains(otherCount),
      (0...Self.maximumTotal).contains(total), total == upperCount + otherCount,
      (0...1_000_000_000_000_000).contains(otherScanBound), padding == [6,5],
      otherRadius == (whole ? (2*depth+2)/5 : dust ? 10 : 0),
      complete == !(sourceLimited.upperCap || sourceLimited.otherScanBound),
      sourceLimited.upperCap == (upperCount == 600_000),
      sourceLimited.otherScanBound == (otherRadius > 0 && otherScanBound > 64),
      (otherRadius != 0 || (otherScanBound == 0 && otherCount == 0)),
      (!sourceLimited.otherScanBound || otherCount == 0)
    else { return false }
    let p = matrix[0], q = matrix[1], r = matrix[2], s = matrix[3]
    // The bounded integer products are transport-consistency checks, not a local catalogue.
    return denominator == p*s-q*r
      && coefficientRows == [s*s,-r*s,r*r,-2*q*s,p*s+q*r,-2*p*r,q*q,-p*q,p*p]
      && cacheKey == "source-catalogue-v1:\(depth):\(matrix.map(String.init).joined(separator: ",")):\(whole ? 1 : 0):\(dust ? 1 : 0)"
  }

  func matches(depth: Int, matrix: [Int], whole: Bool, dust: Bool) -> Bool {
    isValid && self.depth == depth && self.matrix == matrix && self.whole == whole && self.dust == dust
  }

  /// Pages and membership replies may have different request ids, but no other metadata may drift.
  func sameCatalogue(as other: Self) -> Bool {
    isValid && other.isValid && ok == other.ok && schema == other.schema && engine == other.engine
      && sourceCommit == other.sourceCommit && catalogueSchema == other.catalogueSchema
      && catalogueSourceSHA256 == other.catalogueSourceSHA256 && cacheKey == other.cacheKey
      && depth == other.depth && matrix == other.matrix && whole == other.whole && dust == other.dust
      && otherRadius == other.otherRadius && padding == other.padding
      && denominator == other.denominator && coefficientRows == other.coefficientRows
      && upperCount == other.upperCount && otherCount == other.otherCount && total == other.total
      && complete == other.complete && sourceLimited == other.sourceLimited && otherScanBound == other.otherScanBound
  }
}

struct PolynomialCataloguePage: Decodable, Sendable {
  let metadata: PolynomialCatalogueMetadata
  let offset: Int, count: Int, nextOffset: Int?
  let abc: [Int], xyz: [Int], delta: [Int], kind: [Int], divisor: [Int]
  let primitive: [Bool]
  private let uncomputedPlaneFlags: Bool

  private enum CodingKeys: String, CodingKey {
    case offset, count, nextOffset, abc, xyz, delta, kind, divisor, primitive, onPlane, necklace
  }
  init(from decoder: any Decoder) throws {
    metadata = try PolynomialCatalogueMetadata(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    offset = try c.decode(Int.self, forKey: .offset)
    count = try c.decode(Int.self, forKey: .count)
    // Explicit null is required. An omitted continuation/plane field is not a valid terminal page.
    nextOffset = try c.decode(Int?.self, forKey: .nextOffset)
    abc = try c.decode([Int].self, forKey: .abc); xyz = try c.decode([Int].self, forKey: .xyz)
    delta = try c.decode([Int].self, forKey: .delta); kind = try c.decode([Int].self, forKey: .kind)
    divisor = try c.decode([Int].self, forKey: .divisor); primitive = try c.decode([Bool].self, forKey: .primitive)
    uncomputedPlaneFlags = try c.decodeNil(forKey: .onPlane) && c.decodeNil(forKey: .necklace)
  }

  var isValid: Bool {
    guard metadata.isValid, uncomputedPlaneFlags,
      (0...PolynomialCatalogueMetadata.maximumTotal).contains(offset), (0...16384).contains(count),
      count <= max(0, metadata.total-offset),
      abc.count == count*3, xyz.count == count*3,
      [delta.count,kind.count,divisor.count,primitive.count].allSatisfy({ $0 == count }),
      abc.allSatisfy({ (-1024...1024).contains($0) }), xyz.allSatisfy({ (-2048...2048).contains($0) }),
      delta.allSatisfy({ (-5_242_880...5_242_880).contains($0) }),
      divisor.allSatisfy({ (1...1024).contains($0) }),
      nextOffset == (offset+count < metadata.total ? offset+count : nil),
      (count > 0 || offset >= metadata.total)
    else { return false }
    for i in 0..<count {
      let j = i*3, a = abc[j], b = abc[j+1], c = abc[j+2]
      guard a != 0 || b != 0 || c != 0,
        xyz[j] == -b, xyz[j+1] == a+c, xyz[j+2] == c-a,
        delta[i] == b*b-4*a*c,
        kind[i] == (delta[i] == 0 ? 0 : delta[i] > 0 ? 1 : a > 0 ? 2 : 3),
        divisor[i] == Self.gcd(Self.gcd(abs(a),abs(b)),abs(c)), primitive[i] == (divisor[i] == 1),
        (offset+i < metadata.upperCount ? kind[i] == 2 : kind[i] != 2)
      else { return false }
      // Catalogue order restarts once, between the upper and other blocks.
      if i > 0 && offset+i != metadata.upperCount {
        let previous = Array(abc[(j-3)..<j]), current = Array(abc[j..<(j+3)])
        guard previous.lexicographicallyPrecedes(current) else { return false }
      }
    }
    return true
  }

  func matches(depth: Int, matrix: [Int], whole: Bool, dust: Bool, offset: Int) -> Bool {
    isValid && self.offset == offset && metadata.matches(depth: depth, matrix: matrix, whole: whole, dust: dust)
  }

  var points: [PolynomialPoint] {
    guard isValid else { return [] }
    return (0..<count).map { i in
      let j = i*3
      return PolynomialPoint(abc: Array(abc[j..<(j+3)]), xyz: Array(xyz[j..<(j+3)]),
        delta: delta[i], kind: kind[i], divisor: divisor[i], onPlane: false, necklace: false)
    }
  }

  private static func gcd(_ first: Int, _ second: Int) -> Int {
    var a = first, b = second
    while b != 0 { let remainder = a % b; a = b; b = remainder }
    return a
  }
}

struct PolynomialCatalogueMembers: Decodable, Sendable {
  let metadata: PolynomialCatalogueMetadata
  let normal: [Int], count: Int, indices: [Int]

  private enum CodingKeys: String, CodingKey { case normal, count, indices }
  init(from decoder: any Decoder) throws {
    metadata = try PolynomialCatalogueMetadata(from: decoder)
    let c = try decoder.container(keyedBy: CodingKeys.self)
    normal = try c.decode([Int].self, forKey: .normal)
    count = try c.decode(Int.self, forKey: .count)
    indices = try c.decode([Int].self, forKey: .indices)
  }

  var isValid: Bool {
    guard metadata.isValid, normal.count == 3, normal != [0,0,0],
      normal.allSatisfy({ (-PolynomialIdentityBounds.normal...PolynomialIdentityBounds.normal).contains($0) }),
      (0...metadata.total).contains(count), count == indices.count,
      indices.allSatisfy({ (0..<metadata.total).contains($0) })
    else { return false }
    return zip(indices, indices.dropFirst()).allSatisfy { $0 < $1 }
  }

  func matches(metadata expected: PolynomialCatalogueMetadata, normal: [Int]) -> Bool {
    isValid && self.normal == normal && metadata.sameCatalogue(as: expected)
  }

  /// Validate received membership indices against the accepted ordered catalogue, without filling omissions.
  func matches(metadata expected: PolynomialCatalogueMetadata, normal: [Int], points: [PolynomialPoint]) -> Bool {
    guard matches(metadata: expected, normal: normal), points.count == metadata.total else { return false }
    return indices.allSatisfy { index in
      let point = points[index]
      guard point.abc.count == 3, point.abc.allSatisfy({ (-1024...1024).contains($0) }), point.delta < 0 else { return false }
      return normal[1]*point.abc[1] - 2*(normal[0]*point.abc[2]+normal[2]*point.abc[0]) == 0
    }
  }
}

/// Approximate scheduling policy only; the candidate identities are still computed by Lean.
enum PolynomialCataloguePreviewPolicy {
  static let threshold = 0.16
  static func inverseI(_ matrix:[Double]) -> SIMD2<Double>? {
    guard matrix.count == 4, matrix.allSatisfy(\.isFinite) else { return nil }
    let p=matrix[0],q=matrix[1],r=matrix[2],s=matrix[3],d=p*s-q*r,n=p*p+r*r
    guard d > 0,n > 0 else { return nil }
    let z=SIMD2(-(p*q+r*s)/n,d/n)
    return z.x.isFinite && z.y.isFinite && z.y > 0 ? z:nil
  }
  static func displacement(_ first:[Double],_ second:[Double]) -> Double {
    guard let a=inverseI(first),let b=inverseI(second) else { return .infinity }
    return 2*asinh(hypot(a.x-b.x,a.y-b.y)/(2*sqrt(a.y*b.y)))
  }
}
