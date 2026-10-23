// SPDX-License-Identifier: GPL-3.0-or-later
// Actual compiled Lean responses live in lean/Polynomial/fixtures/catalogue-native-cases.json.
// Deliberate JSON mutations below test transport rejection; they are never computation fixtures.
import CryptoKit
import Foundation
import XCTest
@testable import ExteriorRoomCore

private struct CatalogueFixtures {
  struct Entry {
    let request: [String: Any]
    let response: [String: Any]
    var data: Data { get throws { try JSONSerialization.data(withJSONObject: response) } }
  }
  let entries: [Entry]
  let audit: [[String: Any]]
  init() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("lean/Polynomial/fixtures")
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("catalogue-native-cases.json"))) as? [String: Any])
    entries = try XCTUnwrap(object["cases"] as? [[String: Any]]).map {
      Entry(request: try XCTUnwrap($0["request"] as? [String: Any]), response: try XCTUnwrap($0["response"] as? [String: Any]))
    }
    let source = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("source-recrop-audit.json"))) as? [String: Any])
    audit = try XCTUnwrap(source["cases"] as? [[String: Any]])
  }

  func entry(op: String = "catalogue", matrix: [Int] = [1,0,0,1], depth: Int = 6,
             whole: Bool = true, dust: Bool = false, offset: Int = 0, limit: Int = 16384) throws -> Entry {
    try XCTUnwrap(entries.first { entry in
      let r = entry.request
      return r["op"] as? String == op && r["matrix"] as? [Int] == matrix && r["depth"] as? Int == depth
        && (r["whole"] as? Bool ?? true) == whole && (r["dust"] as? Bool ?? false) == dust
        && (op != "catalogue" || ((r["offset"] as? Int ?? 0) == offset && (r["limit"] as? Int ?? 16384) == limit))
    }, "Missing actual Lean fixture for \(op) M=\(matrix), depth=\(depth), whole=\(whole), dust=\(dust), offset=\(offset), limit=\(limit)")
  }
}

private func catalogueData(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
private func cataloguePage(_ object: [String: Any]) throws -> PolynomialCataloguePage {
  try JSONDecoder().decode(PolynomialCataloguePage.self, from: catalogueData(object))
}
private func catalogueAccepted(_ object: [String: Any]) -> Bool {
  (try? cataloguePage(object).isValid) == true
}

final class PolynomialCatalogueTests: XCTestCase {
  func testActualLeanCataloguesMatchPinnedSourceOrderedSignedIdentities() throws {
    let fixtures = try CatalogueFixtures()
    for audited in fixtures.audit {
      let matrix = try XCTUnwrap(audited["matrix"] as? [Int])
      let response = try fixtures.entry(matrix: matrix)
      let page = try JSONDecoder().decode(PolynomialCataloguePage.self, from: response.data)
      XCTAssertTrue(page.matches(depth: 6, matrix: matrix, whole: true, dust: false, offset: 0))
      XCTAssertEqual(page.metadata.total, audited["total"] as? Int)
      XCTAssertEqual(page.metadata.upperCount, audited["upperCatalogCount"] as? Int)
      XCTAssertEqual(page.metadata.otherCount, audited["otherCatalogCount"] as? Int)
      let expected = try XCTUnwrap(audited["upperPoints"] as? [[Int]]) + XCTUnwrap(audited["otherPoints"] as? [[Int]])
      XCTAssertEqual(page.points.map(\.abc), expected)
      let packed = try JSONSerialization.data(withJSONObject: page.points.map(\.abc), options: [.fragmentsAllowed])
      let digest = SHA256.hash(data: packed).map { String(format: "%02x", $0) }.joined()
      XCTAssertEqual(digest, audited["pointListSHA256"] as? String)
    }
  }

  func testIdentityRetainsSignsMultiplesAndBasePrimitiveFlagUnderRationalAction() throws {
    let fixtures = try CatalogueFixtures(), page = try cataloguePage(fixtures.entry().response)
    XCTAssertEqual(page.count, 212)
    XCTAssertTrue(page.points.contains { $0.abc == [1,0,1] && $0.kind == 2 && $0.divisor == 1 })
    XCTAssertTrue(page.points.contains { $0.abc == [-1,0,-1] && $0.kind == 3 && $0.divisor == 1 })
    XCTAssertTrue(page.points.contains { $0.abc == [2,0,2] && $0.kind == 2 && $0.divisor == 2 })
    let rational = try cataloguePage(fixtures.entry(matrix: [2,0,0,1]).response)
    let index = try XCTUnwrap(rational.points.firstIndex { $0.abc == [2,0,2] })
    XCTAssertFalse(rational.primitive[index], "Primitive belongs to the accepted base identity, even when its normalized image is [1,0,4].")
    XCTAssertEqual(rational.points[index].divisor, 2)
    XCTAssertEqual(rational.metadata.denominator, 2)
  }

  func testRationalRowsAndSourceLimitedMetadataAreExplicit() throws {
    let fixtures = try CatalogueFixtures()
    let rational = try cataloguePage(fixtures.entry(matrix: [3,1,1,2]).response)
    XCTAssertEqual(rational.metadata.denominator, 5)
    XCTAssertEqual(rational.metadata.coefficientRows, [4,-2,1,-4,7,-6,1,-3,9])
    XCTAssertTrue(rational.metadata.complete)
    let limited = try cataloguePage(fixtures.entry(matrix: [1,6,0,1]).response)
    XCTAssertTrue(limited.isValid)
    XCTAssertFalse(limited.metadata.complete)
    XCTAssertTrue(limited.metadata.sourceLimited.otherScanBound)
    XCTAssertFalse(limited.metadata.sourceLimited.upperCap)
    XCTAssertGreaterThan(limited.metadata.otherScanBound, 64)
    XCTAssertEqual(limited.metadata.otherCount, 0)
    let dust = try cataloguePage(fixtures.entry(whole: false, dust: true).response)
    XCTAssertEqual(dust.metadata.otherRadius, 10)
    XCTAssertTrue(dust.isValid)
    let upperCap = try cataloguePage(fixtures.entry(depth: 96, whole: false, limit: 1).response)
    XCTAssertTrue(upperCap.isValid)
    XCTAssertEqual(upperCap.metadata.upperCount, 600_000)
    XCTAssertTrue(upperCap.metadata.sourceLimited.upperCap)
    XCTAssertFalse(upperCap.metadata.complete)
    let afterUpperCap = try cataloguePage(fixtures.entry(depth: 96, offset: 600_000, limit: 1).response)
    XCTAssertTrue(afterUpperCap.isValid, "The separately sorted other partition remains addressable after an upper cap.")
    XCTAssertNotEqual(afterUpperCap.kind[0], 2)
  }

  func testActualPagingUsesAbsoluteIndicesAndEmptyBeyondEndSemantics() throws {
    let fixtures = try CatalogueFixtures()
    let full = try cataloguePage(fixtures.entry().response)
    let first = try cataloguePage(fixtures.entry(limit: 17).response)
    let second = try cataloguePage(fixtures.entry(offset: 17, limit: 17).response)
    let final = try cataloguePage(fixtures.entry(offset: 204, limit: 17).response)
    let beyond = try cataloguePage(fixtures.entry(offset: 213, limit: 17).response)
    XCTAssertTrue(first.isValid && second.isValid && beyond.isValid)
    XCTAssertEqual(first.nextOffset, 17)
    XCTAssertEqual(second.nextOffset, 34)
    XCTAssertEqual(first.points + second.points, Array(full.points.prefix(34)))
    XCTAssertTrue(first.metadata.sameCatalogue(as: second.metadata))
    XCTAssertTrue(final.isValid)
    XCTAssertEqual(final.points, Array(full.points.suffix(8)))
    XCTAssertNil(final.nextOffset)
    XCTAssertEqual(beyond.offset, 213)
    XCTAssertEqual(beyond.count, 0)
    XCTAssertNil(beyond.nextOffset)
    XCTAssertTrue(beyond.points.isEmpty)
  }

  func testMembersMatchExactAcceptedCatalogueAndRetainBothSignsAndMultiples() throws {
    let fixtures = try CatalogueFixtures(), page = try cataloguePage(fixtures.entry().response)
    let entry = try fixtures.entry(op: "membersCatalogue")
    let members = try JSONDecoder().decode(PolynomialCatalogueMembers.self, from: entry.data)
    XCTAssertTrue(members.matches(metadata: page.metadata, normal: [1,0,-1], points: page.points))
    let identities = members.indices.map { page.points[$0].abc }
    for point in [[1,0,1],[2,0,2],[-1,0,-1]] { XCTAssertTrue(identities.contains(point)) }
    XCTAssertFalse(members.matches(metadata: page.metadata, normal: [1,3,1]))
    let changed = try cataloguePage(fixtures.entry(matrix: [3,1,1,2]).response)
    XCTAssertFalse(members.matches(metadata: changed.metadata, normal: [1,0,-1]))
  }

  func testRejectsWrongProvenanceEchoRowsLimitsAndCompletionClaims() throws {
    let original = try CatalogueFixtures().entry().response
    let corruptions: [(String, Any)] = [
      ("ok",false), ("id",-1), ("id",9_007_199_254_740_992),
      ("schema","unknown"), ("engine","JavaScript"), ("sourceCommit","wrong"),
      ("catalogueSchema","cloud"), ("catalogueSourceSHA256","wrong"), ("cacheKey","wrong"),
      ("depth",3), ("matrix",[1,0,0,-1]), ("matrix",[1_000_001,0,0,1]),
      ("denominator",2), ("coefficientRows",[1,0,0,0,2,0,0,0,1]),
      ("coefficientRows",[Int.max]), ("padding",[1,1]), ("otherRadius",3),
      ("upperCount",600_001), ("otherCount",-1), ("total",2_000_001),
      ("otherScanBound",1_000_000_000_000_001), ("complete",false),
      ("sourceLimited",["upperCap":true,"otherScanBound":false])
    ]
    for (key, value) in corruptions {
      var object = original; object[key] = value
      XCTAssertFalse(catalogueAccepted(object), "Accepted corrupted \(key): \(value)")
    }
    for key in ["catalogueSourceSHA256","sourceLimited","padding","whole","dust","denominator"] {
      var object = original; object.removeValue(forKey: key)
      XCTAssertFalse(catalogueAccepted(object), "Accepted missing \(key)")
    }
  }

  func testRejectsMalformedPointIdentityOrderAndRequiredNullFields() throws {
    let original = try CatalogueFixtures().entry().response
    for key in ["abc","xyz","delta","kind","divisor","primitive"] {
      var object = original; object[key] = []
      XCTAssertFalse(catalogueAccepted(object), "Accepted wrong-sized \(key)")
    }
    for (key, value) in [("abc",1025),("xyz",2049),("delta",5_242_881),("kind",9),("divisor",0)] {
      var object = original, values = try XCTUnwrap(object[key] as? [Int]); values[0] = value; object[key] = values
      XCTAssertFalse(catalogueAccepted(object), "Accepted out-of-bounds \(key)")
    }
    for (key, value) in [("xyz",0),("delta",0),("kind",3),("divisor",2)] {
      var object = original, values = try XCTUnwrap(object[key] as? [Int]); values[0] = value; object[key] = values
      XCTAssertFalse(catalogueAccepted(object), "Accepted inconsistent \(key)")
    }
    var primitive = original, flags = try XCTUnwrap(original["primitive"] as? [Bool]); flags[0].toggle(); primitive["primitive"] = flags
    XCTAssertFalse(catalogueAccepted(primitive))
    for key in ["onPlane","necklace","nextOffset"] {
      var missing = original; missing.removeValue(forKey: key)
      XCTAssertFalse(catalogueAccepted(missing), "Accepted missing required \(key)")
    }
    for key in ["onPlane","necklace"] {
      var object = original; object[key] = [false]
      XCTAssertFalse(catalogueAccepted(object), "Accepted precomputed \(key)")
    }
    var reordered = original
    // Move complete point records together: the identities remain individually valid but violate catalogue order.
    for key in ["abc","xyz"] {
      var values = try XCTUnwrap(original[key] as? [Int]); let first = Array(values[0..<3])
      values.replaceSubrange(0..<3, with: values[3..<6]); values.replaceSubrange(3..<6, with: first); reordered[key] = values
    }
    for key in ["delta","kind","divisor"] {
      var values = try XCTUnwrap(original[key] as? [Int]); values.swapAt(0,1); reordered[key] = values
    }
    var flagsReordered = try XCTUnwrap(original["primitive"] as? [Bool]); flagsReordered.swapAt(0,1); reordered["primitive"] = flagsReordered
    XCTAssertFalse(catalogueAccepted(reordered))
  }

  func testRejectsBrokenPaginationAndMetadataDriftButAllowsDifferentRequestIDs() throws {
    let fixtures = try CatalogueFixtures(), original = try fixtures.entry(limit: 17).response
    for (key, value) in [("offset",-1),("offset",2_000_001),("count",Int.max),("nextOffset",18)] {
      var object = original; object[key] = value
      XCTAssertFalse(catalogueAccepted(object), "Accepted corrupted \(key)")
    }
    let first = try cataloguePage(original)
    var changedID = original; changedID["id"] = 777
    XCTAssertTrue(first.metadata.sameCatalogue(as: try cataloguePage(changedID).metadata))
    var changedCounts = original
    changedCounts["otherCount"] = first.metadata.otherCount+1; changedCounts["total"] = first.metadata.total+1
    let changed = try cataloguePage(changedCounts)
    XCTAssertTrue(changed.isValid, "This is locally well-formed but belongs to a different catalogue receipt.")
    XCTAssertFalse(first.metadata.sameCatalogue(as: changed.metadata))
  }

  func testRejectsUnorderedDuplicateOutOfRangeAndNonmemberIndices() throws {
    let fixtures = try CatalogueFixtures(), original = try fixtures.entry(op: "membersCatalogue").response
    let page = try cataloguePage(fixtures.entry().response)
    let accepted = try JSONDecoder().decode(PolynomialCatalogueMembers.self, from: catalogueData(original))
    XCTAssertGreaterThan(accepted.count, 1)
    for indices in [[accepted.indices[0],accepted.indices[0]],Array(accepted.indices.reversed()),[-1],[page.metadata.total]] {
      var object = original; object["indices"] = indices; object["count"] = indices.count
      let members = try JSONDecoder().decode(PolynomialCatalogueMembers.self, from: catalogueData(object))
      XCTAssertFalse(members.isValid)
    }
    var wrongNormal = original; wrongNormal["normal"] = [0,0,0]
    XCTAssertFalse(try JSONDecoder().decode(PolynomialCatalogueMembers.self, from: catalogueData(wrongNormal)).isValid)
    let nonmember = try XCTUnwrap(page.points.firstIndex { $0.delta >= 0 })
    var wrongMember = original; wrongMember["indices"] = [nonmember]; wrongMember["count"] = 1
    let member = try JSONDecoder().decode(PolynomialCatalogueMembers.self, from: catalogueData(wrongMember))
    XCTAssertTrue(member.isValid, "An in-range index needs the accepted point array to validate incidence.")
    XCTAssertFalse(member.matches(metadata: page.metadata, normal: [1,0,-1], points: page.points))
  }
}
