// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Renderer-only checks; no Lean proof or gesture claim.
import XCTest
@testable import ExteriorRoomCore

final class PolynomialAppearanceTests: XCTestCase {
  func testReferencePaletteReturnsTheSixPinnedAnchorsWithinConversionTolerance() {
    let anchors = [0xf06a6a,0xe99456,0xd6bd69,0x7ab89b,0x70a6d8,0xad92d0]
    for (index, hex) in anchors.enumerated() {
      let actual = PolynomialAppearance.referenceColor(Double(index) / 5)
      let expected = PolynomialAppearance.rgb(hex)
      // Rounded OKLab matrix constants introduce tiny floating-point conversion differences.
      for channel in 0..<3 { XCTAssertEqual(actual[channel], expected[channel], accuracy: 0.000002, "anchor \(index), channel \(channel)") }
    }
    XCTAssertEqual(PolynomialAppearance.referenceColor(-1), PolynomialAppearance.referenceColor(0))
    XCTAssertEqual(PolynomialAppearance.referenceColor(2), PolynomialAppearance.referenceColor(1))
  }

  func testReferencePalettePreservesCategorySwatchesAndOptInLowerColoring() {
    let upper = point([1,0,1], xyz: [0,2,0], delta: -4, kind: 2)
    let lower = point([-1,0,-1], xyz: [0,-2,0], delta: -4, kind: 3)
    let boundary = point([1,2,1], xyz: [-2,2,0], delta: 0, kind: 0)
    let exterior = point([1,3,1], xyz: [-3,2,0], delta: 5, kind: 1)
    XCTAssertEqual(PolynomialAppearance.color(lower, colorLower: false, palette: "reference"), PolynomialAppearance.rgb(0x64717d))
    XCTAssertEqual(PolynomialAppearance.color(boundary, colorLower: true, palette: "reference"), PolynomialAppearance.rgb(0xd6bd69))
    XCTAssertEqual(PolynomialAppearance.color(exterior, colorLower: true, palette: "reference"), PolynomialAppearance.rgb(0x448abb))
    XCTAssertEqual(PolynomialAppearance.color(lower, colorLower: true, palette: "reference"),
      PolynomialAppearance.color(upper, colorLower: false, palette: "reference"))
  }

  func testDistanceFadeRetainsSelectedAndLeanMembersAndDimsByDistance() {
    // The fixed normal describes z = 0 in display coordinates. These are renderer test inputs.
    let normal: SIMD3<Double> = [0,0,-2]
    let selected = point([1,0,4], xyz: [0,5,3], delta: -16, kind: 2)
    let member = point([1,1,1], xyz: [-1,2,0], delta: -3, kind: 2, necklace: true)
    let near = point([1,0,2], xyz: [0,3,1], delta: -8, kind: 2)
    let far = point([1,0,3], xyz: [0,4,2], delta: -12, kind: 2)
    let distant = point([1,0,4], xyz: [0,5,3], delta: -16, kind: 2)
    let keep = [1,-1,2]
    XCTAssertEqual(PolynomialAppearance.focusFade(selected, position: coordinates(selected), normal: normal, radius: 6, keep: selected.abc), 1)
    XCTAssertEqual(PolynomialAppearance.focusFade(member, position: coordinates(member), normal: normal, radius: 6, keep: keep), 1)
    let nearFade = PolynomialAppearance.focusFade(near, position: coordinates(near), normal: normal, radius: 6, keep: keep)
    let farFade = PolynomialAppearance.focusFade(far, position: coordinates(far), normal: normal, radius: 6, keep: keep)
    XCTAssertGreaterThan(nearFade, farFade)
    XCTAssertGreaterThan(farFade, 0.12)
    XCTAssertEqual(PolynomialAppearance.focusFade(distant, position: coordinates(distant), normal: normal, radius: 6, keep: keep), 0.12, accuracy: 1e-12)
    XCTAssertEqual(PolynomialAppearance.focusFade(near, position: coordinates(near), normal: [0,0,2], radius: 6, keep: keep), nearFade, accuracy: 1e-12)
    XCTAssertEqual(PolynomialAppearance.focusFade(near, position: coordinates(near), normal: [0,0,-20], radius: 6, keep: keep), nearFade, accuracy: 1e-12)
    XCTAssertEqual(PolynomialAppearance.focusFade(near, position: coordinates(near), normal: [0,0,0], radius: 6, keep: keep), 1)
  }

  func testAcceptedRationalActionTransportsPlaneNormalAndFadeTogether() throws {
    let rows = try rationalActionRows()
    let normal = try XCTUnwrap(PolynomialMobius.mapPlaneNormal(rows:rows,[0,0,-2]))
    // Independent rational checkpoint: Q F Q (0,0,-2) = (-2/5,1,-11/5), length √6.
    assertVector(normal,[-2.0/5,1,-11.0/5])
    XCTAssertEqual(normal.x*normal.x+normal.y*normal.y+normal.z*normal.z,6,accuracy:1e-12)
    let near = point([1,0,2],xyz:[0,3,1],delta:-8,kind:2)
    let far = point([1,0,3],xyz:[0,4,2],delta:-12,kind:2)
    let distant = point([1,0,4],xyz:[0,5,3],delta:-16,kind:2)
    let images = try [near,far,distant].map { p in
      try XCTUnwrap(PolynomialMobius.mapDisplayCoordinates(rows:rows,coordinates(p)))
    }
    assertVector(images[0],[16.0/5,5,13.0/5])
    let expected = [0.8399267649983406,0.5016363422089475,0.19802265495519855]
    for (index,p) in [near,far,distant].enumerated() {
      let image = images[index]
      let incidence = normal.x*image.x+normal.y*image.y+normal.z*image.z
      XCTAssertEqual(incidence,-2*Double(index+1),accuracy:1e-12)
      let fade = PolynomialAppearance.focusFade(p,position:image,normal:normal,radius:6,keep:[])
      XCTAssertEqual(fade,expected[index],accuracy:1e-12)
      XCTAssertEqual(PolynomialAppearance.focusFade(p,position: -image,normal:normal,radius:6,keep:[]),fade,accuracy:1e-12)
      XCTAssertEqual(PolynomialAppearance.focusFade(p,position:image,normal:normal * -20,radius:6,keep:[]),fade,accuracy:1e-12)
    }
    let oldDistanceFade = PolynomialAppearance.focusFade(near,position:coordinates(near),normal:[0,0,-2],radius:6,keep:[])
    XCTAssertNotEqual(oldDistanceFade,expected[0],"Using base coordinates must fail this regression")
    for member in [point([1,0,1],xyz:[0,2,0],delta:-4,kind:2,necklace:true),
      point([1,1,1],xyz:[-1,2,0],delta:-3,kind:2,necklace:true)] {
      let image = try XCTUnwrap(PolynomialMobius.mapDisplayCoordinates(rows:rows,coordinates(member)))
      XCTAssertEqual(normal.x*image.x+normal.y*image.y+normal.z*image.z,0,accuracy:1e-12)
      XCTAssertEqual(PolynomialAppearance.focusFade(member,position:image,normal:normal,radius:6,keep:[]),1)
    }
    XCTAssertEqual(PolynomialAppearance.focusFade(distant,position:images[2],normal:normal,radius:6,keep:distant.abc),1)
  }

  func testPlaneNormalTransportUsesCovectorSignsAndRejectsNonfiniteInput() throws {
    let rows = try rationalActionRows()
    let normal = SIMD3<Double>(0,0,-2)
    let mapped = try XCTUnwrap(PolynomialMobius.mapPlaneNormal(rows:rows,normal))
    let incorrectlyMappedAsPoint = try XCTUnwrap(PolynomialMobius.mapDisplayCoordinates(rows:rows,normal))
    XCTAssertEqual(mapped.y,1,accuracy:1e-12)
    XCTAssertEqual(incorrectlyMappedAsPoint.y,-1,accuracy:1e-12)
    XCTAssertNotEqual(mapped,incorrectlyMappedAsPoint)
    XCTAssertEqual(PolynomialMobius.mapPlaneNormal(rows:[1,0,0,0,1,0,0,0,1],normal),normal)
    XCTAssertNil(PolynomialMobius.mapPlaneNormal(rows:[],normal))
    XCTAssertNil(PolynomialMobius.mapPlaneNormal(rows:rows,[.infinity,0,0]))
    let p = point([1,0,2],xyz:[0,3,1],delta:-8,kind:2)
    XCTAssertEqual(PolynomialAppearance.focusFade(p,position:[.nan,0,0],normal:normal,radius:6,keep:[]),1)
    XCTAssertEqual(PolynomialAppearance.focusFade(p,position:coordinates(p),normal:normal,radius:0,keep:[]),1)
  }

  private func rationalActionRows() throws -> [Double] {
    struct Fixtures: Decodable {
      struct Item: Decodable { let name: String; let response: PolynomialAction }
      let cases: [Item]
    }
    let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-action-cases.json"))
    let cases = try JSONDecoder().decode(Fixtures.self,from:data).cases
    let action = try XCTUnwrap(cases.first { $0.name == "rational/default" }?.response)
    XCTAssertTrue(action.isValid)
    return try XCTUnwrap(action.coefficientRowsApprox)
  }
  private func coordinates(_ point: PolynomialPoint) -> SIMD3<Double> {
    [Double(point.xyz[0]),Double(point.xyz[1]),Double(point.xyz[2])]
  }
  private func assertVector(_ actual: SIMD3<Double>,_ expected: SIMD3<Double>) {
    for channel in 0..<3 { XCTAssertEqual(actual[channel],expected[channel],accuracy:1e-12) }
  }

  private func point(_ abc: [Int], xyz: [Int], delta: Int, kind: Int, necklace: Bool = false) -> PolynomialPoint {
    PolynomialPoint(abc: abc, xyz: xyz, delta: delta, kind: kind, divisor: 1, onPlane: necklace, necklace: necklace)
  }
}
