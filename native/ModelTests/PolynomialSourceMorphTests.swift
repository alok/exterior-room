// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only parity against offline evaluation of Katherine Stange's pinned source.
// These fixtures are not Lean proof outputs, app execution, GPU or headset evidence.
import XCTest
@testable import ExteriorRoomCore

private struct SourceMorphFixture: Decodable {
  struct Timing: Decodable {
    let durationMillisecondsPerUnit: Int
    let elapsedFractions: [Double]
    let easedProgress: [Double]
    let sliderImmediate: Bool
    let reducedMotionImmediate: Bool
  }
  struct Settings: Decodable {
    let R: Int
    let whole: Bool
    let dust: Bool
    let screen: Bool
    let eye: Double
    let theme: String
    let normal: [Int]?
    let hf: Double
    let sigma: Double
    let projection: Double
    var native: PolynomialSourceMorph.Settings {
      var settings = PolynomialSourceMorph.Settings(depth:R)
      settings.whole = whole; settings.dust = dust; settings.screen = screen
      settings.eye = eye; settings.light = theme == "light"; settings.hasPlane = normal != nil
      settings.heightFraction = hf; settings.sigma = sigma; settings.progress = projection
      return settings
    }
  }
  struct Sample: Decodable {
    struct Body: Decodable {
      struct Packed: Decodable {
        let displayXYZ: [Double]
        let radius: Double
        let alpha: Double
        let passesSourceAlphaPickGate: Bool
      }
      let packedFloat32: Packed
    }
    let name: String
    let abc: [Int]
    let catalogued: Bool
    let sourceKind: Int?
    let basePrimitive: Bool?
    let baseDiscriminant: Int?
    let transformedABC: [Double]?
    let planeMember: Bool?
    let body: Body?
  }
  struct Marker: Decodable {
    let baseABC: [Int]
    let packedFloat32: [Double]
  }
  struct Case: Decodable {
    let profile: String
    let settings: Settings
    let matrix: [Int]
    let normalizedMatrix: [Double]
    let points: [Sample]
    let markers: [Marker]
    var label: String { "\(profile) M=\(matrix) p=\(settings.projection)" }
  }
  let schema: String
  let sourceSHA256: String
  let timing: Timing
  let cases: [Case]

  static func load() throws -> Self {
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try JSONDecoder().decode(Self.self,from:Data(contentsOf:
      root.appendingPathComponent("lean/Polynomial/fixtures/source-projection-morph.json")))
  }
}

final class PolynomialSourceMorphTests: XCTestCase {
  func testPlaneClippingPreservesPlaneAndSourceAsymmetricLimits() throws {
    let normal=SIMD3<Double>(1,2,3)
    for point:SIMD3<Double> in [[6,-3,0],[0,9,-6],[-12,0,4]] {
      let q=try XCTUnwrap(PolynomialSourceMorph.clipPlaneVertex(point,radius:2))
      XCTAssertEqual(normal.x*q.x+normal.y*q.y+normal.z*q.z,0,accuracy:1e-12)
      XCTAssertLessThanOrEqual(hypot(q.x,q.z),2+1e-12)
      XCTAssertLessThanOrEqual(q.y,2+1e-12); XCTAssertGreaterThanOrEqual(q.y,-0.6-1e-12)
      XCTAssertLessThanOrEqual(hypot(hypot(q.x,q.y),q.z),3+1e-12)
    }
    XCTAssertNil(PolynomialSourceMorph.clipPlaneVertex([0,0,0],radius:0))
  }
  func testPreviewDistanceAndIntegerDisplayIncidenceBounds() {
    XCTAssertEqual(PolynomialCataloguePreviewPolicy.displacement([1,0,0,1],[2,0,0,1]),log(2),accuracy:1e-12)
    XCTAssertEqual(PolynomialCataloguePreviewPolicy.displacement([1,0,0,1],[-2,0,0,-2]),0,accuracy:1e-12)
    XCTAssertTrue(PolynomialCataloguePreviewPolicy.displacement([1,0,0,1],[0,0,0,0]).isInfinite)
    for abc in [[1,2,1],[0,1,0],[-1,-2,-1],[1024,1024,1024]] {
      XCTAssertTrue(PolynomialSourceMorph.incident(abc,normal:[1,0,-1]))
    }
    XCTAssertFalse(PolynomialSourceMorph.incident([1,0,2],normal:[1,0,-1]))
    XCTAssertFalse(PolynomialSourceMorph.incident([1025,0,0],normal:[1,0,-1]))
  }

  private func divisor(_ abc:[Int]) -> Int {
    abc.reduce(0) { partial,value in
      var a = partial, b = abs(value)
      while b != 0 { (a,b) = (b,a%b) }
      return a
    }
  }
  private func display(_ abc:[Double]) throws -> SIMD3<Double> {
    XCTAssertEqual(abc.count,3)
    guard abc.count == 3 else { throw URLError(.cannotParseResponse) }
    return SIMD3(-abc[1],abc[0]+abc[2],abc[2]-abc[0])
  }
  /// Float32 packing can differ by a small number of ULPs after libm operations.
  private func assertPacked(_ actual:Float,_ expected:Double,_ label:String,file:StaticString=#filePath,line:UInt=#line) {
    let value = Float(expected)
    XCTAssertTrue(actual.isFinite,label,file:file,line:line)
    XCTAssertEqual(actual,value,accuracy:max(4*value.ulp,1e-7),label,file:file,line:line)
  }

  func testAll48SourceProfilesMatchPackedBodyPositionsRadiiAlphaAndPickGate() throws {
    let fixture = try SourceMorphFixture.load()
    XCTAssertEqual(fixture.schema,"source-projection-morph-audit-v1")
    XCTAssertEqual(fixture.sourceSHA256,"f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b")
    XCTAssertEqual(fixture.cases.count,48)
    let sourceToNativeKind = [2,0,1,3]
    var compared = 0, uncatalogued = 0
    for item in fixture.cases {
      for sample in item.points {
        guard let expected = sample.body?.packedFloat32 else {
          XCTAssertFalse(sample.catalogued,"\(item.label) \(sample.name)")
          uncatalogued += 1; continue
        }
        let sourceKind = try XCTUnwrap(sample.sourceKind)
        XCTAssertTrue(sourceToNativeKind.indices.contains(sourceKind))
        let abc = sample.abc, gcd = divisor(abc), label = "\(item.label) \(sample.name)"
        XCTAssertEqual(sample.basePrimitive,gcd == 1,label)
        let point = PolynomialPoint(abc:abc,xyz:[-abc[1],abc[0]+abc[2],abc[2]-abc[0]],
          delta:try XCTUnwrap(sample.baseDiscriminant),kind:sourceToNativeKind[sourceKind],divisor:gcd,
          onPlane:try XCTUnwrap(sample.planeMember),necklace:false)
        // The input comes from the independently recorded transformed coefficients,
        // never from the expected projected position, radius or alpha.
        let shown = try display(XCTUnwrap(sample.transformedABC))
        let actual = PolynomialSourceMorph.body(point:point,shown:shown,settings:item.settings.native)
        XCTAssertEqual(expected.displayXYZ.count,3,label)
        for axis in 0..<3 { assertPacked(actual.position[axis],expected.displayXYZ[axis],label) }
        assertPacked(actual.radius,expected.radius,label)
        assertPacked(actual.alpha,expected.alpha,label)
        XCTAssertEqual(actual.pickable,expected.passesSourceAlphaPickGate,label)
        compared += 1
      }
    }
    XCTAssertEqual(compared,408); XCTAssertEqual(uncatalogued,72)
  }

  func testSelectedAndPairedMarkersFollowMorphWithoutMovingLowerSelections() throws {
    let fixture = try SourceMorphFixture.load()
    var compared = 0, supplementalLower = 0
    for item in fixture.cases {
      for marker in item.markers {
        let sample = item.points.first { $0.abc == marker.baseABC }
        let shown: SIMD3<Double>, upper: Bool
        if let abc = sample?.transformedABC {
          shown = try display(abc); upper = sample?.sourceKind == 0
        } else {
          // The source's second lower marker is intentionally outside the body-sample list.
          // Map its base coefficients through the independent action helper, not marker output.
          XCTAssertEqual(item.profile,"lower-selection"); XCTAssertEqual(marker.baseABC,[-1,-1,-1])
          let rows = try XCTUnwrap(PolynomialMobius.coefficientRows(item.normalizedMatrix))
          let abc = try XCTUnwrap(PolynomialMobius.applyRows(rows,SIMD3(-1,-1,-1)))
          shown = try display([abc.x,abc.y,abc.z]); upper = false; supplementalLower += 1
        }
        let actual = PolynomialSourceMorph.markerPosition(shown,upper:upper,settings:item.settings.native)
        XCTAssertEqual(marker.packedFloat32.count,5)
        // Source x/z axes are opposite the application's display axes.
        let expected = [-marker.packedFloat32[0],marker.packedFloat32[1],-marker.packedFloat32[2]]
        for axis in 0..<3 { assertPacked(actual[axis],expected[axis],"\(item.label) marker \(marker.baseABC)") }
        if !upper {
          for axis in 0..<3 { assertPacked(actual[axis],shown[axis],"Lower marker stays in its accepted position") }
        }
        compared += 1
      }
    }
    XCTAssertEqual(compared,84); XCTAssertEqual(supplementalLower,6)
  }

  func testSourceEaseSamplesAndClampedEndpoints() throws {
    let timing = try SourceMorphFixture.load().timing
    XCTAssertEqual(timing.durationMillisecondsPerUnit,3500)
    XCTAssertTrue(timing.sliderImmediate); XCTAssertTrue(timing.reducedMotionImmediate)
    XCTAssertEqual(timing.elapsedFractions.count,5); XCTAssertEqual(timing.easedProgress.count,5)
    for (time,expected) in zip(timing.elapsedFractions,timing.easedProgress) {
      XCTAssertEqual(PolynomialSourceMorph.ease(time),expected,accuracy:1e-12)
    }
    XCTAssertEqual(PolynomialSourceMorph.ease(-1),0)
    XCTAssertEqual(PolynomialSourceMorph.ease(2),1)
  }
}
