// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Pure response/preview tests; no gesture-execution claim.
import XCTest
@testable import ExteriorRoomCore

private struct ActionFixtures: Decodable {
  struct Case: Decodable {
    struct Request: Decodable { let matrix: [Int], point: [Int], id: Int }
    let name: String, request: Request, response: PolynomialAction
    let canonicalImage: [Int]?
  }
  let cases: [Case]
  static func load() throws -> ActionFixtures {
    try JSONDecoder().decode(Self.self, from: data())
  }
  static func data() throws -> Data {
    let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-action-cases.json"))
  }
  func named(_ name: String) throws -> PolynomialAction {
    try XCTUnwrap(cases.first { $0.name == name }).response
  }
}

final class PolynomialActionTests: XCTestCase {
  func testActualLeanActionsMatchEveryCanonicalSignedGeneratorFixture() throws {
    let fixtures = try ActionFixtures.load()
    XCTAssertEqual(fixtures.cases.count, 69)
    XCTAssertEqual(fixtures.cases.filter { $0.canonicalImage != nil }.count, 33)
    for item in fixtures.cases {
      let action = item.response
      XCTAssertTrue(action.isValid, item.name)
      XCTAssertTrue(action.matches(matrix: item.request.matrix, point: item.request.point), item.name)
      XCTAssertEqual(action.id, item.request.id)
      if let expected = item.canonicalImage { XCTAssertEqual(action.image, expected, item.name) }
    }
    let positive = try fixtures.named("T/default"), negative = try fixtures.named("T/default-sign-partner")
    let multiple = try fixtures.named("T/default-multiple")
    XCTAssertEqual(negative.imageNumerator, positive.imageNumerator.map { -$0 })
    XCTAssertEqual(multiple.imageNumerator, positive.imageNumerator.map { 2*$0 })
    XCTAssertEqual(positive.delta, -7); XCTAssertEqual(negative.delta, -7); XCTAssertEqual(multiple.delta, -28)
    XCTAssertEqual(try fixtures.named("S/user-seed").image, [34,-20,13])
  }

  func testActualRationalDragCheckpointAndDisplayMappingKeepExactNumerators() throws {
    let fixtures = try ActionFixtures.load(), action = try fixtures.named("rational/default")
    XCTAssertEqual(action.matrix, [3,1,1,2]); XCTAssertEqual(action.denominator, 5)
    XCTAssertEqual(action.coefficientRows, [4,-2,1,-4,7,-6,1,-3,9])
    XCTAssertEqual(action.imageNumerator, [8,-23,22]); XCTAssertEqual(action.xyzNumerator, [23,30,14])
    XCTAssertEqual(action.delta, -7); XCTAssertNil(action.image)
    close(try XCTUnwrap(action.mapCoefficients([1,-1,2])), [1.6,-4.6,4.4])
    let display = try XCTUnwrap(action.mapDisplay([1,3,1]))
    close(SIMD3(Double(display.x),Double(display.y),Double(display.z)), [4.6,6,2.8], tolerance: 1e-6)
    XCTAssertEqual(try fixtures.named("rational/x2+1").image, [1,-2,2])
    let scaled = try fixtures.named("rational-scaled/default")
    XCTAssertEqual(scaled.denominator, 20)
    XCTAssertEqual(scaled.imageNumerator, action.imageNumerator.map { 4*$0 })
    XCTAssertEqual(scaled.coefficientRowsApprox, action.coefficientRowsApprox)
    XCTAssertEqual(scaled.mapDisplay([1,3,1]), action.mapDisplay([1,3,1]))
  }

  func testActualSimulatorSwipeReceiptPreservesDiscriminantsAndPairedPlaneIncidence() throws {
    struct SwipeFixture: Decodable {
      struct Members: Decodable { let radius: Int, total: Int, count: Int, indices: [Int] }
      let captureRun: String
      let primary: PolynomialAction, secondary: PolynomialAction, pair: PolynomialPlane, members: Members
    }
    let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    let fixture = try JSONDecoder().decode(SwipeFixture.self,
      from:Data(contentsOf:native.appendingPathComponent("Resources/polynomial-swipe-case.json")))
    XCTAssertEqual(fixture.captureRun,"20261023T070446Z")
    let matrix = [13876,5301,5706,9386], denominator = 99_992_630
    XCTAssertTrue(fixture.primary.matches(matrix:matrix,point:[1,0,1]))
    XCTAssertTrue(fixture.secondary.matches(matrix:matrix,point:[1,1,1]))
    XCTAssertEqual(fixture.primary.denominator,denominator)
    XCTAssertEqual(fixture.primary.imageNumerator,[120655432,-257863284,220643977])
    XCTAssertEqual(fixture.secondary.imageNumerator,[67098916,-97375642,147087301])
    XCTAssertEqual(fixture.primary.delta,-4); XCTAssertEqual(fixture.secondary.delta,-3)
    XCTAssertTrue(fixture.pair.isValidPair)
    XCTAssertEqual(fixture.pair.cartesianNormal,[0,0,-2])
    XCTAssertEqual(fixture.members.radius,6); XCTAssertEqual(fixture.members.total,480)
    XCTAssertEqual(fixture.members.count,22); XCTAssertEqual(Set(fixture.members.indices).count,22)
    XCTAssertTrue(fixture.members.indices.allSatisfy { (0..<480).contains($0) })

    // This captured matrix is small enough for exact Int64 diagnostic products. Do not
    // generalize these products to the service's maximum bounds, which require Lean Int.
    let rows = fixture.primary.coefficientRows
    let a = rows[0]-rows[2], b = rows[3]-rows[5], c = rows[6]-rows[8]
    let normalNumerator = [-b,-a-c,c-a] // Q F Q (0,0,-2), with denominator D.
    for action in [fixture.primary,fixture.secondary] {
      XCTAssertTrue(action.isValid)
      XCTAssertEqual(action.coefficientRows,rows)
      let all = action.imageNumerator + action.xyzNumerator + normalNumerator
      guard all.allSatisfy({ abs($0) < 1_000_000_000 }), action.denominator == denominator else {
        XCTFail("Captured fixture exceeds this test's safe Int64 diagnostic bounds"); return
      }
      let image = action.imageNumerator
      XCTAssertEqual(image[1]*image[1]-4*image[0]*image[2],action.delta*denominator*denominator)
      XCTAssertEqual(zip(normalNumerator,action.xyzNumerator).map { $0 * $1 }.reduce(0,+),0)
    }
  }

  func testActionDecoderRejectsMalformedProvenanceNamedChecksBoundsAndMaps() throws {
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ActionFixtures.data()) as? [String: Any])
    let cases = try XCTUnwrap(root["cases"] as? [[String: Any]])
    let sample = try XCTUnwrap(cases.first { $0["name"] as? String == "rational/default" }?["response"] as? [String: Any])
    let mutations: [(String, Any)] = [
      ("ok",false), ("id",-1), ("schema","other"), ("sourceCommit","other"), ("engine","other"),
      ("actionSchema","other"), ("actionSourceCommit","other"), ("matrix",[1,0,0]),
      ("matrix",[Int.max,0,0,1]), ("matrix",[1,0,0,-1]), ("denominator",0), ("denominator",Int.max),
      ("denominator",6), ("point",[0,0,0]), ("point",[1025,0,1]), ("point",[1,-1]),
      ("coefficientRows",[4,-2,1,-4,7,-6,1,-3,10]), ("coefficientRows",Array(repeating:Int.max,count:9)),
      ("imageNumerator",[8,-23,23]), ("xyzNumerator",[23,30,15]), ("delta",-6), ("image",[1,-4,4]),
      ("checks",["unrelated":true]), ("checks",["positiveDeterminant":true]),
      ("checks",["discriminantPreserved":true]),
      ("checks",["positiveDeterminant":true,"discriminantPreserved":false]),
    ]
    for (field,value) in mutations {
      var changed = sample; changed[field] = value
      let action = try JSONDecoder().decode(PolynomialAction.self, from: JSONSerialization.data(withJSONObject: changed))
      XCTAssertFalse(action.isValid, "Accepted malformed \(field)")
      XCTAssertNil(action.coefficientRowsApprox)
      XCTAssertNil(action.mapDisplay([1,3,1]))
    }
    for missing in ["image","checks","actionSourceCommit","coefficientRows"] {
      var changed = sample; changed.removeValue(forKey: missing)
      XCTAssertThrowsError(try JSONDecoder().decode(PolynomialAction.self, from: JSONSerialization.data(withJSONObject: changed)), missing)
    }
    let good = try ActionFixtures.load().named("rational/default")
    XCTAssertFalse(good.matches(matrix:[1,0,0,1], point:good.point))
    XCTAssertFalse(good.matches(matrix:good.matrix, point:[1,0,1]))
  }

  func testPreviewTransvectionMovesItsAnchorAndMatchesDocumentedCheckpoint() throws {
    let points: [SIMD2<Double>] = [[0,1],[1,2],[-0.3,0.05],[4,7],[-2.5,0.4]]
    for z0 in points { for z1 in points {
      let move = try XCTUnwrap(PolynomialMobius.transvection(z0,z1))
      close(try XCTUnwrap(PolynomialMobius.act(move,z0)), z1, tolerance: 1e-8)
      XCTAssertEqual(move[0]*move[3]-move[1]*move[2],1,accuracy:1e-8)
    } }
    let checkpoint = try XCTUnwrap(PolynomialMobius.transvection([0,1],[1,1]))
    for (actual,expected) in zip(checkpoint,[3.0,1,1,2].map { $0/sqrt(5) }) {
      XCTAssertEqual(actual,expected,accuracy:1e-12)
    }
    let rows = try XCTUnwrap(PolynomialMobius.coefficientRows(checkpoint))
    close(try XCTUnwrap(PolynomialMobius.applyRows(rows,[1,-1,2])),[1.6,-4.6,4.4])
  }

  func testPreviewDragComposesOnTheLeftAndKleinChartRoundTrips() throws {
    var matrix = PolynomialMobius.identity
    let base = SIMD2<Double>(0.3,1.7)
    var previous = base
    for target: SIMD2<Double> in [[0.5,1.5],[2,0.8],[-1,3]] {
      matrix = try XCTUnwrap(PolynomialMobius.dragStep(matrix,from:previous,to:target))
      close(try XCTUnwrap(PolynomialMobius.act(matrix,base)),target,tolerance:1e-8)
      previous = target
    }
    for z: SIMD2<Double> in [[0,1],[1,2],[-0.3,0.05],[4,7],[-2.5,0.4]] {
      let chart = try XCTUnwrap(PolynomialMobius.upperToKlein(z))
      close(try XCTUnwrap(PolynomialMobius.kleinToUpper(chart)),z,tolerance:1e-9)
    }
    XCTAssertNil(PolynomialMobius.kleinToUpper([1,0]))
    XCTAssertNil(PolynomialMobius.kleinToUpper([0.6,0.9]))
    XCTAssertNil(PolynomialMobius.kleinToUpper([.nan,0]))
    XCTAssertNil(PolynomialMobius.upperToKlein([0,0]))
  }

  func testQuantizationProducesBoundedPositiveDeterminantRequestsAndRejectsDegeneracy() throws {
    XCTAssertEqual(PolynomialMobius.quantizedMatrix([1,1,0,1]),[1,1,0,1])
    XCTAssertEqual(PolynomialMobius.quantizedMatrix([0,-1,1,0]),[0,-1,1,0])
    let move = try XCTUnwrap(PolynomialMobius.transvection([0,1],[1,1]))
    XCTAssertEqual(PolynomialMobius.quantizedMatrix(move),[3,1,1,2])
    let request = try XCTUnwrap(PolynomialMobius.quantizedMatrix([1,200,0,1]))
    XCTAssertTrue(request.allSatisfy { (-1_000_000...1_000_000).contains($0) })
    XCTAssertGreaterThan(request[0]*request[3]-request[1]*request[2],0)
    XCTAssertEqual(PolynomialMobius.normalize([Double.greatestFiniteMagnitude,0,0,Double.greatestFiniteMagnitude]),PolynomialMobius.identity)
    for invalid: [Double] in [[],[1,0,0],[1,0,0,-1],[1,1,1,1],[.infinity,0,0,1],[.nan,0,0,1]] {
      XCTAssertNil(PolynomialMobius.normalize(invalid)); XCTAssertNil(PolynomialMobius.quantizedMatrix(invalid))
    }
    XCTAssertNil(PolynomialMobius.quantizedMatrix([1,1,1,1+1e-8]))
    XCTAssertNil(PolynomialMobius.quantizedMatrix(PolynomialMobius.identity,precision:0))
    XCTAssertNil(PolynomialMobius.quantizedMatrix(PolynomialMobius.identity,precision:Int.max))
  }

  func testPreviewCancellationAndRevisionMismatchCannotProduceACommitValue() throws {
    let accepted = PolynomialMobius.identity
    var preview = try XCTUnwrap(PolynomialActionPreview(matrix:accepted,kleinPoint:[0,0],inputRevision:7))
    let target = try XCTUnwrap(PolynomialMobius.upperToKlein([1,1]))
    XCTAssertTrue(preview.update(kleinPoint:target))
    XCTAssertEqual(preview.commitMatrix(ifRevision:7),[3,1,1,2])
    XCTAssertNil(preview.commitMatrix(ifRevision:8))
    let before = preview
    XCTAssertFalse(preview.update(kleinPoint:[1,0]))
    XCTAssertEqual(preview,before)
    // An out-of-disk release does not invent an endpoint image: commit retains the last
    // valid preview sample. This is distinct from cancellation, which removes the sample.
    XCTAssertEqual(preview.commitMatrix(ifRevision:7),before.commitMatrix(ifRevision:7))
    preview.cancel()
    XCTAssertEqual(preview.matrix,accepted); XCTAssertTrue(preview.isCancelled)
    XCTAssertNil(preview.commitMatrix(ifRevision:7)); XCTAssertFalse(preview.update(kleinPoint:target))
    XCTAssertEqual(accepted,PolynomialMobius.identity)
    XCTAssertNil(PolynomialActionPreview(matrix:accepted,kleinPoint:[1,0],inputRevision:7))
  }

  func testSnapMatchesPinnedCanonicalBrowserFixturesIncludingSignedMatricesAndRoundingTies() throws {
    struct SnapFixtures: Decodable {
      struct Case: Decodable { let name: String, matrix: [Double], expected: [Int]? }
      let sourceCommit: String, cases: [Case]
    }
    let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let bytes = try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-polar-snap-cases.json"))
    let fixture = try JSONDecoder().decode(SnapFixtures.self, from: bytes)
    XCTAssertEqual(fixture.sourceCommit, "2cd549a45ddb6056cf3596404754d96ad9e7132c")
    XCTAssertEqual(fixture.cases.count, 34)
    for item in fixture.cases {
      let result = PolynomialMobius.nearestIntegral(item.matrix)
      XCTAssertEqual(result, item.expected, item.name)
      guard item.expected != nil else { continue }
      let proposed = try XCTUnwrap(result,item.name)
      XCTAssertEqual(proposed[0]*proposed[3]-proposed[1]*proposed[2], 1, item.name)
      XCTAssertTrue(proposed.allSatisfy { (-1_000_000...1_000_000).contains($0) }, item.name)
    }
    XCTAssertEqual(PolynomialMobius.nearestIntegral([1,-0.5,0,1]), [1,0,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral([1,0.5,0,1]), [1,1,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral([1,-1.5,0,1]), [1,-1,0,1])
  }

  func testPolarSnapFixesRecordedSourceCounterexampleAndSignConvention() throws {
    let recorded = [3.162278103784889,1.1384199665329495,4.0371747379733554e-16,0.31622772165519336]
    XCTAssertEqual(PolynomialMobius.nearestIntegral(recorded),[1,4,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral(recorded.map { -$0 }),[1,4,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral([50,18,0,5]),[1,4,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral([-1,0,0,-1]),[1,0,0,1])
    XCTAssertEqual(try XCTUnwrap(PolynomialMobius.polarAngle(PolynomialMobius.identity)),0,accuracy:1e-15)
    XCTAssertEqual(try XCTUnwrap(PolynomialMobius.polarAngle([0,-1,1,0])),.pi/2,accuracy:1e-15)
    XCTAssertEqual(try XCTUnwrap(PolynomialMobius.polarAngle([cos(0.3),-sin(0.3),sin(0.3),cos(0.3)])),0.3,accuracy:1e-15)
    XCTAssertNil(PolynomialMobius.polarAngle([.infinity,0,0,1]))
  }

  func testSnapRejectsNonfiniteDegenerateAndUnboundedRequestsWithoutIntegerOverflow() {
    for invalid: [Double] in [[],[1,0,0],[1,0,0,-1],[1,1,1,1],
      [.nan,0,0,1],[1,.infinity,0,1],[1,2_000_000,0,1],
      [Double.greatestFiniteMagnitude,1,0,Double.leastNonzeroMagnitude]] {
      XCTAssertNil(PolynomialMobius.nearestIntegral(invalid), "Accepted unsafe Snap proposal \(invalid)")
    }
    XCTAssertEqual(PolynomialMobius.nearestIntegral([1,999,0,1]), [1,999,0,1])
    XCTAssertEqual(PolynomialMobius.nearestIntegral([-1,-999,0,-1]), [1,999,0,1])
  }

  func testShownRealEndpointsHandleInfinityAndPolesWithoutChangingBaseValues() throws {
    XCTAssertEqual(try XCTUnwrap(PolynomialMobius.actReal([3,1,1,2],-1)),-2,accuracy:1e-14)
    XCTAssertEqual(try XCTUnwrap(PolynomialMobius.actReal([3,1,1,2],1)),4.0/3,accuracy:1e-14)
    XCTAssertEqual(PolynomialMobius.actReal([3,1,1,2],.infinity),3)
    XCTAssertEqual(PolynomialMobius.actReal([0,-1,1,0],0),.infinity)
    XCTAssertEqual(PolynomialMobius.actReal([0,-1,1,0],.infinity),0)
    XCTAssertNil(PolynomialMobius.actReal([0,0,0,0],1))
    XCTAssertNil(PolynomialMobius.actReal(PolynomialMobius.identity,.nan))
  }

  private func close(_ a: SIMD2<Double>, _ b: SIMD2<Double>, tolerance: Double = 1e-10,
    file: StaticString = #filePath, line: UInt = #line) {
    for i in 0..<2 { XCTAssertEqual(a[i],b[i],accuracy:tolerance*max(1,abs(b[i])),file:file,line:line) }
  }
  private func close(_ a: SIMD3<Double>, _ b: SIMD3<Double>, tolerance: Double = 1e-10,
    file: StaticString = #filePath, line: UInt = #line) {
    for i in 0..<3 { XCTAssertEqual(a[i],b[i],accuracy:tolerance*max(1,abs(b[i])),file:file,line:line) }
  }
}
