// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23.
// Model transaction tests; they do not assert a physical or synthesized gesture succeeds.
import XCTest
@testable import ExteriorRoomCore

private struct PairingFixtures: Sendable {
  let cloud: Data
  let initial: Data
  let cases: [String:Data]
  let spatialCases: [Data]

  init() throws {
    let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    cloud = try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-cloud-r6.json"))
    initial = try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-default.json"))
    let bytes = try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-test-cases.json"))
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with:bytes) as? [String:Any])
    cases = try object.mapValues { try JSONSerialization.data(withJSONObject:$0) }
    let spatialURL = native.deletingLastPathComponent()
      .appendingPathComponent("lean/Polynomial/fixtures/spatial-pair-native-cases.json")
    let spatial = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:spatialURL)) as? [String:Any])
    spatialCases = try XCTUnwrap(spatial["cases"] as? [[String:Any]]).map {
      try JSONSerialization.data(withJSONObject:$0)
    }
  }

  func response(to input:[String:Any]) throws -> Data {
    // Match actual recorded requests, including unreduced signed identities.
    for data in spatialCases {
      let item = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
      var expected = try XCTUnwrap(item["request"] as? [String:Any]), actual = input
      expected.removeValue(forKey:"id"); actual.removeValue(forKey:"id")
      if NSDictionary(dictionary:actual).isEqual(to:expected) {
        return try JSONSerialization.data(withJSONObject:XCTUnwrap(item["response"]))
      }
    }
    switch input["op"] as? String {
    case "inspect":
      let point = try XCTUnwrap(input["point"] as? [Int])
      for data in [initial] + Array(cases.values) {
        if let detail = try? JSONDecoder().decode(PolynomialInspection.self,from:data), detail.point == point { return data }
      }
    case "pair":
      guard input["first"] as? [Int] == [1,0,1], input["second"] as? [Int] == [1,1,1] else { break }
      return try XCTUnwrap(cases["pair"])
    case "members":
      guard input["radius"] as? Int == 6, input["upperOnly"] as? Bool == false,
        input["normal"] as? [Int] == [1,0,-1] else { break }
      return try XCTUnwrap(cases["members"])
    default: break
    }
    throw URLError(.unsupportedURL)
  }
}

/// All payloads are real compiled-Lean exports. Only the request sequence ID changes.
/// A held response deliberately ignores task cancellation, exercising the model's stale guard.
private actor PairingTransport {
  struct Pending {
    let request: URLRequest
    let data: Data
    let continuation: CheckedContinuation<(Data,URLResponse),any Error>
  }
  let fixtures: PairingFixtures
  private var holdOperation: String?
  private var pending: Pending?
  private var operationCounts: [String:Int] = [:]
  private var pairInputs: [[[Int]]] = []

  init(_ fixtures:PairingFixtures) { self.fixtures = fixtures }
  func hold(_ operation:String) { holdOperation = operation }
  func count(_ operation:String) -> Int { operationCounts[operation,default:0] }
  func total() -> Int { operationCounts.values.reduce(0,+) }
  func lastPair() -> [[Int]]? { pairInputs.last }

  func send(_ request:URLRequest) async throws -> (Data,URLResponse) {
    let input = try XCTUnwrap(JSONSerialization.jsonObject(with:XCTUnwrap(request.httpBody)) as? [String:Any])
    let operation = try XCTUnwrap(input["op"] as? String), id = try XCTUnwrap(input["id"] as? Int)
    operationCounts[operation,default:0] += 1
    if operation == "pair" {
      pairInputs.append([try XCTUnwrap(input["first"] as? [Int]),try XCTUnwrap(input["second"] as? [Int])])
    }
    var output = try XCTUnwrap(JSONSerialization.jsonObject(with:fixtures.response(to:input)) as? [String:Any])
    output["id"] = id
    let data = try JSONSerialization.data(withJSONObject:output)
    guard holdOperation == operation else { return (data,response(request)) }
    return try await withCheckedThrowingContinuation { continuation in
      pending = Pending(request:request,data:data,continuation:continuation)
    }
  }
  func waitForHeld() async throws {
    for _ in 0..<1000 {
      if pending != nil { return }
      try await Task.sleep(for:.milliseconds(1))
    }
    throw URLError(.timedOut)
  }
  func release(failing:Bool = false) throws {
    let held = try XCTUnwrap(pending)
    pending = nil; holdOperation = nil
    if failing { held.continuation.resume(throwing:URLError(.notConnectedToInternet)) }
    else { held.continuation.resume(returning:(held.data,response(held.request))) }
  }
  private func response(_ request:URLRequest) -> HTTPURLResponse {
    HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!
  }
}

@MainActor final class PolynomialPairingTests: XCTestCase {
  private func makeModel(_ fixtures:PairingFixtures,_ transport:PairingTransport) -> PolynomialModel {
    PolynomialModel(cloudData:fixtures.cloud,inspectionData:fixtures.initial,
      transport:{ try await transport.send($0) })
  }

  private func sphereIdentity(_ abc:[Int], in model:PolynomialModel) throws -> [Int] {
    let snapshot = try XCTUnwrap(PolynomialRenderPlan.make(points:model.points,
      rows:[1,0,0,0,1,0,0,0,1],radius:6,origin:false,starSize:1,colorLower:false,
      palette:"viridis",normal:nil,keep:[],projection:false))
    let glyph = try XCTUnwrap(snapshot.glyphs.first { $0.point.abc == abc })
    return try XCTUnwrap(snapshot.pick(at:glyph.position)?.abc)
  }

  func testDefaultPrimaryPairsWithActualUnreducedSphereIdentityAfterMembershipAccepts() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick([1,-1,2]); await model.waitForPending()
    XCTAssertNil(model.error)
    let accepted = model.points, revision = model.sceneRevision
    let picked = try sphereIdentity([3,0,3],in:model)
    XCTAssertEqual(picked,[3,0,3]); XCTAssertNotEqual(picked,[1,0,1])
    await transport.hold("members")
    model.armPairNext(true); model.pick(picked)
    try await transport.waitForHeld()
    XCTAssertTrue(model.pairNext); XCTAssertTrue(model.busy)
    XCTAssertEqual(model.selected,[1,-1,2]); XCTAssertEqual(model.inspection?.point,[1,-1,2])
    XCTAssertEqual(model.paired,[3,0,3]); XCTAssertNil(model.displayedPair)
    XCTAssertNil(model.pairedInspection); XCTAssertNil(model.plane)
    XCTAssertEqual(model.points,accepted); XCTAssertEqual(model.sceneRevision,revision)
    let sentPair = await transport.lastPair()
    XCTAssertEqual(sentPair,[[1,-1,2],[3,0,3]])
    try await transport.release(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy); XCTAssertFalse(model.pairNext)
    XCTAssertEqual(model.selected,[1,-1,2]); XCTAssertEqual(model.inspection?.point,[1,-1,2])
    XCTAssertEqual(model.paired,[3,0,3]); XCTAssertEqual(model.displayedPair,[3,0,3])
    XCTAssertEqual(model.pairedInspection?.point,[3,0,3])
    XCTAssertEqual(model.pairedInspection?.primitive,[1,0,1]); XCTAssertEqual(model.pairedInspection?.divisor,3)
    let plane = try XCTUnwrap(model.plane)
    XCTAssertEqual(plane.normal,[1,-2,-1]); XCTAssertEqual(plane.planeCoefficients,[2,-2,-2])
    XCTAssertEqual(plane.endpoints.map(\.kind),["surd","surd"])
    XCTAssertEqual(plane.endpoints.map(\.p),[1,1]); XCTAssertEqual(plane.endpoints.map(\.sign),[-1,1])
    XCTAssertEqual(plane.endpoints.map(\.s),[1,1]); XCTAssertEqual(plane.endpoints.map(\.r),[2,2])
    XCTAssertEqual(plane.endpoints.map(\.q),[1,1])
    XCTAssertEqual(model.points.filter(\.necklace).count,18)
    XCTAssertEqual(model.sceneRevision,revision+1)
  }

  func testSameDirectionSpherePairRejectsAndKeepsUnreducedPrimaryAndPairNextArmed() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick(try sphereIdentity([3,0,3],in:model)); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.inspection?.point,[3,0,3])
    let accepted = model.points, revision = model.sceneRevision
    model.armPairNext(true); model.pick(try sphereIdentity([1,0,1],in:model))
    await model.waitForPending()
    let expected = try JSONDecoder().decode(PolynomialHeader.self,from:fixtures.response(to:
      ["op":"pair","first":[3,0,3],"second":[1,0,1]]))
    XCTAssertFalse(expected.ok); XCTAssertNotNil(expected.error); XCTAssertEqual(model.error,expected.error)
    XCTAssertTrue(model.pairNext); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected,[3,0,3]); XCTAssertEqual(model.inspection?.point,[3,0,3])
    XCTAssertNil(model.paired); XCTAssertNil(model.displayedPair); XCTAssertNil(model.pairedInspection)
    XCTAssertNil(model.plane); XCTAssertEqual(model.points,accepted); XCTAssertEqual(model.sceneRevision,revision)
    let sentPair = await transport.lastPair(), memberships = await transport.count("members")
    XCTAssertEqual(sentPair,[[3,0,3],[1,0,1]]); XCTAssertEqual(memberships,0)
  }

  func testSharedPickDisarmsOnlyAfterTheWholePairIsAccepted() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick([1,0,1]); await model.waitForPending()
    XCTAssertNil(model.error)
    let revision = model.sceneRevision
    await transport.hold("members")
    model.armPairNext(true); model.pick([1,1,1])
    try await transport.waitForHeld()
    XCTAssertTrue(model.pairNext); XCTAssertTrue(model.busy)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertNil(model.displayedPair)
    XCTAssertNil(model.plane); XCTAssertEqual(model.sceneRevision,revision)
    try await transport.release(); await model.waitForPending()
    XCTAssertFalse(model.pairNext); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertEqual(model.pairedInspection?.point,[1,1,1]); XCTAssertEqual(model.plane?.normal,[1,0,-1])
    XCTAssertEqual(model.points.filter(\.necklace).count,22)
    XCTAssertEqual(model.sceneRevision,revision+1)
    // The next unarmed pick is a selection, not a second accidental pairing.
    model.pick([1,-1,2]); await model.waitForPending()
    XCTAssertEqual(model.inspection?.point,[1,-1,2]); XCTAssertNil(model.displayedPair)
    XCTAssertNil(model.plane)
    let pairs = await transport.count("pair"); XCTAssertEqual(pairs,1)
  }

  func testRejectedPickKeepsPairingArmedAndDoesNotReplaceAcceptedControls() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick([1,0,1]); await model.waitForPending()
    model.armPairNext(true)
    let calls = await transport.total(), revision = model.sceneRevision
    model.pick([13,20,34]) // Deliberately outside the accepted R6 catalogue.
    XCTAssertTrue(model.pairNext); XCTAssertNotNil(model.error)
    XCTAssertEqual(model.selected,[1,0,1]); XCTAssertNil(model.paired)
    let afterRejectedPick = await transport.total(); XCTAssertEqual(afterRejectedPick,calls)
    await transport.hold("pair")
    model.pick([1,1,1]); try await transport.waitForHeld()
    try await transport.release(failing:true); await model.waitForPending()
    XCTAssertTrue(model.pairNext); XCTAssertFalse(model.busy); XCTAssertNotNil(model.error)
    XCTAssertEqual(model.selected,[1,0,1]); XCTAssertNil(model.paired)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertNil(model.displayedPair)
    XCTAssertEqual(model.sceneRevision,revision)
  }

  func testCancelDuringPairRequestRestoresAcceptedPairAndIgnoresLateMembership() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick([1,0,1]); await model.waitForPending()
    model.armPairNext(true); model.pick([1,1,1]); await model.waitForPending()
    XCTAssertNil(model.error)
    let revision = model.sceneRevision, ids = model.points.map(\.id)
    let memberIDs = model.points.filter(\.necklace).map(\.id)
    await transport.hold("members")
    model.armPairNext(true); model.pick([1,1,1]); try await transport.waitForHeld()
    model.cancelPairing()
    XCTAssertFalse(model.pairNext); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    XCTAssertEqual(model.selected,[1,0,1]); XCTAssertEqual(model.paired,[1,1,1])
    XCTAssertEqual(model.displayedPair,[1,1,1]); XCTAssertEqual(model.plane?.normal,[1,0,-1])
    try await transport.release(); await model.waitForPending()
    XCTAssertFalse(model.pairNext); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    XCTAssertEqual(model.sceneRevision,revision); XCTAssertEqual(model.points.map(\.id),ids)
    XCTAssertEqual(model.points.filter(\.necklace).map(\.id),memberIDs)
    XCTAssertEqual(model.selected,[1,0,1]); XCTAssertEqual(model.paired,[1,1,1])
  }

  func testResetClearsArmedModeAndAcceptedPair() async throws {
    let fixtures = try PairingFixtures(), transport = PairingTransport(fixtures)
    let model = makeModel(fixtures,transport)
    model.pick([1,0,1]); await model.waitForPending()
    model.armPairNext(true); model.pick([1,1,1]); await model.waitForPending()
    model.armPairNext(true); XCTAssertTrue(model.pairNext)
    model.reset(); XCTAssertFalse(model.pairNext)
    await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected,[1,-1,2]); XCTAssertEqual(model.inspection?.point,[1,-1,2])
    XCTAssertNil(model.paired); XCTAssertNil(model.displayedPair); XCTAssertNil(model.pairedInspection)
    XCTAssertNil(model.plane); XCTAssertTrue(model.points.allSatisfy { !$0.necklace })
  }
}
