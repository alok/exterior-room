// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Fixtures are actual compiled Lean responses.
import CryptoKit
import XCTest
@testable import ExteriorRoomCore

private struct PolynomialFixtures: Sendable {
  let cloud: Data
  let initial: Data
  let cases: [String: Data]
  let actions: [Data]
  let polar: [Data]
  let catalogues: [Data]
  let density: [Data]

  init() throws {
    let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    cloud = try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-cloud-r6.json"))
    initial = try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-default.json"))
    let bytes = try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-test-cases.json"))
    let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    cases = try objects.mapValues { try JSONSerialization.data(withJSONObject: $0) }
    let actionBytes = try Data(contentsOf: native.appendingPathComponent("Resources/polynomial-action-cases.json"))
    let actionRoot = try polynomialObject(actionBytes)
    let actionCases = try XCTUnwrap(actionRoot["cases"] as? [[String: Any]])
    actions = try actionCases.map { try JSONSerialization.data(withJSONObject: XCTUnwrap($0["response"])) }
    let polarRoot = try polynomialObject(Data(contentsOf:native.appendingPathComponent("Resources/polynomial-polar-lean-cases.json")))
    let catalogueRoot = try polynomialObject(Data(contentsOf:native.deletingLastPathComponent().appendingPathComponent("lean/Polynomial/fixtures/catalogue-native-cases.json")))
    let densityRoot = try polynomialObject(Data(contentsOf:native.appendingPathComponent("ModelTests/Fixtures/polynomial-density-cases.json")))
    let previewRoot = try polynomialObject(Data(contentsOf:native.appendingPathComponent("ModelTests/Fixtures/polynomial-preview-cases.json")))
    density = try (XCTUnwrap(densityRoot["cases"] as? [[String:Any]]) + XCTUnwrap(previewRoot["cases"] as? [[String:Any]])).map { try JSONSerialization.data(withJSONObject:$0) }
    catalogues = try XCTUnwrap(catalogueRoot["cases"] as? [[String:Any]]).map { try JSONSerialization.data(withJSONObject:$0) }
    polar = try XCTUnwrap(polarRoot["cases"] as? [[String:Any]]).map { try JSONSerialization.data(withJSONObject:$0) }
  }

  func response(for input: [String: Any]) throws -> Data {
    for data in polar + density {
      let item = try polynomialObject(data), request = try XCTUnwrap(item["request"] as? [String:Any])
      if NSDictionary(dictionary:request.filter { $0.key != "id" }).isEqual(to:input.filter { $0.key != "id" }) {
        return try JSONSerialization.data(withJSONObject:XCTUnwrap(item["response"]))
      }
    }
    if ["catalogue","membersCatalogue"].contains(input["op"] as? String ?? "") {
      for data in catalogues {
        let item = try polynomialObject(data), request = try XCTUnwrap(item["request"] as? [String:Any])
        let same = request["op"] as? String == input["op"] as? String
          && request["depth"] as? Int == input["depth"] as? Int
          && request["matrix"] as? [Int] == input["matrix"] as? [Int]
          && (request["whole"] as? Bool ?? true) == (input["whole"] as? Bool ?? true)
          && (request["dust"] as? Bool ?? false) == (input["dust"] as? Bool ?? false)
          && (request["offset"] as? Int ?? 0) == (input["offset"] as? Int ?? 0)
          && request["normal"] as? [Int] == input["normal"] as? [Int]
        if same { return try JSONSerialization.data(withJSONObject:XCTUnwrap(item["response"])) }
      }
      throw URLError(.unsupportedURL)
    }
    switch input["op"] as? String {
    case "cloud":
      guard input["radius"] as? Int == 6, input["upperOnly"] as? Bool == false,
        input["offset"] as? Int == 0 else { throw URLError(.unsupportedURL) }
      return cloud
    case "inspect":
      let desired = try XCTUnwrap(input["point"] as? [Int])
      for data in [initial] + Array(cases.values) {
        if let detail = try? JSONDecoder().decode(PolynomialInspection.self, from: data), detail.point == desired { return data }
      }
    case "transform":
      let matrix = try XCTUnwrap(input["matrix"] as? [Int]), point = try XCTUnwrap(input["point"] as? [Int])
      for data in actions {
        let action = try JSONDecoder().decode(PolynomialAction.self, from: data)
        if action.matrix == matrix, action.point == point { return data }
      }
    case "pair":
      if input["first"] as? [Int] == [1,0,1], input["second"] as? [Int] == [1,1,1] {
        return try XCTUnwrap(cases["pair"])
      }
      if input["first"] as? [Int] == [1,-2,2], input["second"] as? [Int] == [1,-1,1] {
        return try XCTUnwrap(cases["pair-T"])
      }
      if input["first"] as? [Int] == [96,-96,96], input["second"] as? [Int] == [1,0,1] {
        return try XCTUnwrap(cases["pair-action-bound-first"])
      }
      if input["first"] as? [Int] == [1,0,1], input["second"] as? [Int] == [-96,96,-96] {
        return try XCTUnwrap(cases["pair-action-bound-second"])
      }
      throw URLError(.unsupportedURL)
    case "plane", "members":
      let operation = try XCTUnwrap(input["op"] as? String)
      let normal = try XCTUnwrap(input["normal"] as? [Int])
      if operation == "members" {
        guard input["radius"] as? Int == 6, input["upperOnly"] as? Bool == false
        else { throw URLError(.unsupportedURL) }
      }
      switch normal {
      case [1,0,-1]: return try XCTUnwrap(cases[operation])
      case [1,3,1]: return try XCTUnwrap(cases[operation + "-exterior"])
      case [1,-2,0] where operation == "members": return try XCTUnwrap(cases["members-pair-T"])
      default: throw URLError(.unsupportedURL)
      }
    default: break
    }
    throw URLError(.unsupportedURL)
  }
}

private func polynomialObject(_ data: Data) throws -> [String: Any] {
  try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func changedPolynomial(_ data: Data, field: String, value: Any) throws -> Data {
  var object = try polynomialObject(data)
  object[field] = value
  return try JSONSerialization.data(withJSONObject: object)
}

/// Returns genuine exported results with only transport sequence numbers changed.
/// Held responses intentionally ignore cancellation so the model's stale-response guard is exercised.
private actor PolynomialTransport {
  enum Corruption: Sendable {
    case wrongID, falseOK, wrongSchema, wrongCommit, wrongGeometry
    case wrongActionCommit, missingActionCheck, wrongActionPoint
  }
  struct Pending {
    let request: URLRequest
    let data: Data
    let continuation: CheckedContinuation<(Data, URLResponse), any Error>
  }
  let fixtures: PolynomialFixtures
  private var heldOperation: String?
  private var held: [Int: Pending] = [:]
  private var observed: [Int] = []
  private var operationCounts: [String: Int] = [:]

  init(_ fixtures: PolynomialFixtures) { self.fixtures = fixtures }
  func hold(operation: String = "inspect") { heldOperation = operation }
  func count(operation: String) -> Int { operationCounts[operation, default: 0] }
  func totalCount() -> Int { operationCounts.values.reduce(0, +) }
  func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let input = try polynomialObject(XCTUnwrap(request.httpBody))
    let id = try XCTUnwrap(input["id"] as? Int)
    let operation = try XCTUnwrap(input["op"] as? String)
    operationCounts[operation, default: 0] += 1
    let data = try changedPolynomial(fixtures.response(for: input), field: "id", value: id)
    if heldOperation != operation { return (data, response(request)) }
    observed.append(id)
    return try await withCheckedThrowingContinuation {
      held[id] = Pending(request: request, data: data, continuation: $0)
    }
  }
  func waitForHeld(_ count: Int) async throws -> [Int] {
    for _ in 0..<1000 {
      if observed.count >= count { return observed }
      try await Task.sleep(for: .milliseconds(1))
    }
    throw URLError(.timedOut)
  }
  func reply(_ id: Int, corrupt: Corruption? = nil) throws {
    let pending = try XCTUnwrap(held.removeValue(forKey: id))
    var data = pending.data
    switch corrupt {
    case .wrongID: data = try changedPolynomial(data, field: "id", value: id + 100)
    case .falseOK: data = try changedPolynomial(data, field: "ok", value: false)
    case .wrongSchema: data = try changedPolynomial(data, field: "schema", value: "unrecognized-v2")
    case .wrongCommit: data = try changedPolynomial(data, field: "sourceCommit", value: "unrecognized-source")
    case .wrongGeometry: data = try changedPolynomial(data, field: "xyz", value: [0,0,0])
    case .wrongActionCommit: data = try changedPolynomial(data, field: "actionSourceCommit", value: "unrecognized-action")
    case .missingActionCheck: data = try changedPolynomial(data, field: "checks", value: ["positiveDeterminant": true])
    case .wrongActionPoint: data = try changedPolynomial(data, field: "point", value: [1,0,1])
    case nil: break
    }
    pending.continuation.resume(returning: (data, response(pending.request)))
  }
  func fail(_ id: Int) throws {
    try XCTUnwrap(held.removeValue(forKey: id)).continuation.resume(throwing: URLError(.notConnectedToInternet))
  }
  private func response(_ request: URLRequest) -> HTTPURLResponse {
    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
  }
}

@MainActor final class PolynomialModelTests: XCTestCase {
  private func model(_ fixtures: PolynomialFixtures, _ transport: PolynomialTransport) -> PolynomialModel {
    PolynomialModel(cloudData: fixtures.cloud, inspectionData: fixtures.initial,
      transport: { try await transport.send($0) })
  }

  func testSpatialOriginDragUsesSameExactActionAndRejectsStaleCrossSurfaceEnd() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.beginSpatialDrag(direction:[0,2,0]); XCTAssertNil(model.actionPreview)
    model.place(.origin(lower:false)); model.beginSpatialDrag(direction:[0,2,0])
    model.updateSpatialDrag(direction:[2,3,1],force:true)
    XCTAssertTrue(model.ownsSpatialDrag); XCTAssertNotNil(model.actionPreview)
    XCTAssertTrue(model.commitSpatialDrag()); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.action?.matrix,[3,1,1,2])
    let accepted=model.action?.matrix,revision=model.sceneRevision
    model.beginSpatialDrag(direction:[0,2,0]); model.updateSpatialDrag(direction:[2,3,1],force:true)
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[0,2],force:true)
    let roots=model.actionPreview
    XCTAssertFalse(model.commitSpatialDrag()); XCTAssertEqual(model.actionPreview,roots)
    model.cancelRootsDrag(); XCTAssertEqual(model.action?.matrix,accepted); XCTAssertEqual(model.sceneRevision,revision)
  }
  func testSpatialCancelNappeFlipAndOutsideInteriorCannotCommitAnOldPreview() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.place(.origin(lower:false)); let revision=model.sceneRevision
    model.beginSpatialDrag(direction:[0,2,0]); model.updateSpatialDrag(direction:[2,3,1],force:true)
    model.cancelSpatialDrag(); XCTAssertNil(model.actionPreview); XCTAssertEqual(model.sceneRevision,revision)
    model.beginSpatialDrag(direction:[0,2,0]); model.updateSpatialDrag(direction:[2,3,1],force:true)
    model.placement = .origin(lower:true)
    XCTAssertFalse(model.commitSpatialDrag()); XCTAssertNil(model.actionPreview)
    model.beginSpatialDrag(direction:[2,1,0]); XCTAssertNil(model.actionPreview)
    model.updateSpatialDrag(direction:[0,-2,0],force:true)
    XCTAssertNotNil(model.actionPreview); XCTAssertFalse(model.commitSpatialDrag())
    XCTAssertEqual(model.sceneRevision,revision); XCTAssertNil(model.action)
  }

  func testPreviewRecropPublishesOnlyEphemeralSignedCatalogueAndCancelRestoresAccepted() async throws {
    let fixture=try PolynomialFixtures(), transport=PolynomialTransport(fixture), model=model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    let ids=model.points.map(\.id),revision=model.sceneRevision
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[0,2],force:true)
    await model.waitForPreviewCatalogue()
    XCTAssertEqual(model.previewCatalogue?.matrix,[2,0,0,1]); XCTAssertEqual(model.renderPoints.count,186)
    XCTAssertEqual(model.renderPoints.filter(\.necklace).count,10)
    XCTAssertEqual(model.points.map(\.id),ids); XCTAssertEqual(model.sceneRevision,revision)
    XCTAssertEqual(model.catalogue?.matrix,[1,0,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertFalse(model.busy); XCTAssertNotNil(model.actionPreview)
    model.cancelRootsDrag()
    XCTAssertNil(model.previewCatalogue); XCTAssertNil(model.previewPoints)
    XCTAssertEqual(model.renderPoints.map(\.id),ids); XCTAssertEqual(model.sceneRevision,revision)
  }
  func testPreviewLatestRequestWinsAndCancellationIgnoresLateMembership() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    let ids=model.points.map(\.id),revision=model.sceneRevision
    await transport.hold(operation:"membersCatalogue")
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[0,2],force:true)
    let first=try await transport.waitForHeld(1)
    model.updateRootsDrag(to:[0,4],force:true)
    try await transport.reply(first[0])
    let second=try await transport.waitForHeld(2)
    XCTAssertNil(model.previewPoints,"Obsolete candidate cannot publish while newer sample is pending")
    model.cancelRootsDrag(); try await transport.reply(second[1])
    for _ in 0..<5 { await Task.yield() }
    XCTAssertNil(model.previewPoints); XCTAssertEqual(model.sceneRevision,revision)
    XCTAssertEqual(model.points.map(\.id),ids); XCTAssertEqual(model.displayedPair,[1,1,1])
  }
  func testFailedPreviewRecropKeepsPreviousPreviewAndAcceptedPair() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[0,2],force:true); await model.waitForPreviewCatalogue()
    let previous=model.renderPoints.map(\.id)
    await transport.hold(operation:"catalogue")
    model.updateRootsDrag(to:[0,4],force:true)
    let held=try await transport.waitForHeld(1); try await transport.reply(held[0],corrupt:.wrongGeometry)
    await model.waitForPreviewCatalogue()
    XCTAssertEqual(model.renderPoints.map(\.id),previous); XCTAssertEqual(model.previewCatalogue?.matrix,[2,0,0,1])
    XCTAssertTrue(model.previewCatalogueStatus.contains("unavailable")); XCTAssertEqual(model.previewCatalogueAcceptances,1)
    XCTAssertEqual(model.catalogue?.matrix,[1,0,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    model.cancelRootsDrag()
  }

  func testReturningDragToAcceptedCropInvalidatesDistantPendingReply() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    await transport.hold(operation:"catalogue")
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[0,2],force:true)
    let held=try await transport.waitForHeld(1)
    model.updateRootsDrag(to:[0,1],force:true); try await transport.reply(held[0])
    for _ in 0..<5 { await Task.yield() }
    XCTAssertNil(model.previewPoints); XCTAssertEqual(model.renderPoints.count,212)
    XCTAssertNotNil(model.actionPreview)
    model.cancelRootsDrag()
  }
  func testSourceProjectionChangesNoExactCatalogueOrIdentityAndReducedMotionIsImmediate() async throws {
    let fixture=try PolynomialFixtures(),transport=PolynomialTransport(fixture),model=model(fixture,transport)
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    let count=await transport.totalCount(),revision=model.sceneRevision,ids=model.points.map(\.id)
    model.setProjection(true,reducedMotion:true)
    XCTAssertEqual(model.projectionProgress,1); XCTAssertFalse(model.projectionAnimating)
    model.setProjectionProgress(0.5); model.projectionHeightFraction=0.75
    XCTAssertEqual(model.sourceMorphSettings?.height,4.5)
    XCTAssertEqual(model.sceneRevision,revision); XCTAssertEqual(model.points.map(\.id),ids)
    let after=await transport.totalCount(); XCTAssertEqual(after,count)
    model.reset(); await model.waitForPending()
    XCTAssertEqual(model.projectionProgress,0); XCTAssertEqual(model.projectionHeightFraction,0.6)
  }

  func testR24PagesKeepAllActualLeanSignedIdentitiesAndReset() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.radius = 24; model.refresh(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.displayedRadius,24); XCTAssertEqual(model.points.count,28832)
    XCTAssertEqual(Set(model.points.map(\.id)).count,28832)
    XCTAssertTrue(model.points.contains { $0.abc == [-12,0,-12] })
    XCTAssertTrue(model.points.contains { $0.abc == [12,0,12] })
    let requests = await transport.count(operation:"cloud"); XCTAssertEqual(requests,2)
    model.reset(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.points.count,480); XCTAssertEqual(model.displayedRadius,6)
  }

  func testSourceRationalActionRecataloguesAndFailedFollowupRetainsWholeScene() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    model.requestAction([3,1,1,2]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.catalogue?.matrix,[3,1,1,2])
    XCTAssertEqual(model.action?.matrix,[3,1,1,2]); XCTAssertEqual(model.points.filter(\.necklace).count,19)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    let ids = model.points.map(\.id), revision = model.sceneRevision
    await transport.hold(operation:"membersCatalogue")
    model.requestAction([1,0,0,1])
    let requests = try await transport.waitForHeld(1)
    XCTAssertEqual(model.catalogue?.matrix,[3,1,1,2]); XCTAssertEqual(model.points.map(\.id),ids)
    try await transport.fail(requests[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertEqual(model.actionMatrix,[3,1,1,2]); XCTAssertEqual(model.sceneRevision,revision)
    XCTAssertEqual(model.catalogue?.matrix,[3,1,1,2]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertEqual(model.points.map(\.id),ids); XCTAssertEqual(model.points.filter(\.necklace).count,19)
  }

  func testSourceCatalogueStagesSignedPairAndIdentityWithoutLosingBaseIdentity() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.catalogueMode = .source; model.refresh(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.points.count,212)
    XCTAssertEqual(model.catalogue?.total,212); XCTAssertEqual(model.catalogue?.matrix,[1,0,0,1])
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertEqual(model.points.filter(\.necklace).count,24)
    let ids = model.points.map(\.id)
    let requestsBefore = await transport.count(operation:"catalogue")
    model.requestAction([1,0,0,1]); await model.waitForPending()
    let requestsAfter = await transport.count(operation:"catalogue")
    XCTAssertEqual(requestsAfter,requestsBefore+1,"Identity forces a source recatalogue")
    XCTAssertNil(model.error); XCTAssertEqual(model.points.map(\.id),ids)
    XCTAssertEqual(model.displayedPair,[1,1,1])
  }

  func testFailedSourceModeAndConfigRequestRestoreAllAcceptedControls() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.refresh(); await model.waitForPending()
    let baseline = model.points.map(\.id), revision = model.sceneRevision
    await transport.hold(operation:"catalogue")
    model.catalogueMode = .source; model.refresh()
    let requests = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy); XCTAssertEqual(model.points.map(\.id),baseline); XCTAssertNil(model.catalogue)
    try await transport.fail(requests[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertEqual(model.catalogueMode,.ball); XCTAssertEqual(model.radius,6)
    XCTAssertTrue(model.whole); XCTAssertFalse(model.dust); XCTAssertNil(model.catalogue)
    XCTAssertEqual(model.sceneRevision,revision); XCTAssertEqual(model.points.map(\.id),baseline)
    model.radius = 48; model.upperOnly = true; model.whole = false; model.dust = true; model.refresh()
    await model.waitForPending()
    XCTAssertEqual(model.radius,6); XCTAssertFalse(model.upperOnly); XCTAssertTrue(model.whole); XCTAssertFalse(model.dust)
  }

  func testFailedSourceMembershipKeepsEntirePreviousPairAndCatalogue() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    let baseline = model.points.map(\.id), revision = model.sceneRevision
    await transport.hold(operation:"membersCatalogue")
    model.catalogueMode = .source; model.refresh()
    let requests = try await transport.waitForHeld(1)
    XCTAssertNil(model.catalogue); XCTAssertEqual(model.points.map(\.id),baseline)
    try await transport.fail(requests[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertEqual(model.catalogueMode,.ball)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertEqual(model.points.filter(\.necklace).count,22); XCTAssertEqual(model.sceneRevision,revision)
  }

  func testSourceDustAndResetUseActualLeanCatalogues() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.catalogueMode = .source; model.whole = false; model.dust = true; model.refresh(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.points.count,3311)
    XCTAssertEqual(model.catalogue?.otherRadius,10); XCTAssertFalse(model.whole); XCTAssertTrue(model.dust)
    model.reset(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertNil(model.catalogue); XCTAssertEqual(model.catalogueMode,.ball)
    XCTAssertEqual(model.points.count,480); XCTAssertEqual(model.radius,6); XCTAssertTrue(model.whole); XCTAssertFalse(model.dust)
  }

  func testRootsDragAtOverviewUsesSameDeclaredActionAndKeepsBasePair() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    XCTAssertEqual(model.placement,.overview)
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[1,1],force:true)
    XCTAssertNotNil(model.actionPreview)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertNil(model.action)
    model.commitRootsDrag(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.action?.matrix,[3,1,1,2])
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    XCTAssertEqual(model.plane?.normal,[1,0,-1]); XCTAssertEqual(model.points.filter(\.necklace).count,22)
    XCTAssertEqual(model.placement,.overview)
  }

  func testRootsAndKleinPreviewOwnershipCancellationAndInvalidAxis() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.beginRootsDrag(at:[0,0]); XCTAssertNil(model.actionPreview)
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[1,1],force:true)
    let preview = try XCTUnwrap(model.actionPreview)
    model.updateRootsDrag(to:[1,0],force:true); XCTAssertEqual(model.actionPreview,preview)
    model.updateActionDrag(to:[0,0],force:true); XCTAssertEqual(model.actionPreview,preview,"Other surface cannot mutate a Roots preview")
    model.cancelActionDrag(); model.commitRootsDrag()
    XCTAssertNil(model.actionPreview); XCTAssertNil(model.action)
    let calls = await transport.totalCount(); XCTAssertEqual(calls,0)
    model.beginRootsDrag(at:[0,1]); model.place(.origin(lower:false)); XCTAssertNil(model.actionPreview)
    model.beginActionDrag(at:[0,0]); let klein = model.actionPreview
    model.updateRootsDrag(to:[1,1],force:true); XCTAssertEqual(model.actionPreview,klein)
    model.reset(); await model.waitForPending(); XCTAssertNil(model.actionPreview)
    XCTAssertEqual(model.rootsResetRevision,1)
  }

  func testEndingOldSurfaceCannotCommitOrCancelNewSurfacePreview() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.place(.origin(lower:false))
    model.beginActionDrag(at:[0,0])
    model.beginRootsDrag(at:[0,1]); model.updateRootsDrag(to:[1,1],force:true)
    let roots = try XCTUnwrap(model.actionPreview)
    XCTAssertFalse(model.commitActionDrag()); model.cancelKleinDrag()
    XCTAssertEqual(model.actionPreview,roots); XCTAssertFalse(model.busy)
    model.beginActionDrag(at:[0,0]); model.updateActionDrag(to:[0.1,0],force:true)
    let klein = try XCTUnwrap(model.actionPreview)
    XCTAssertFalse(model.commitRootsDrag()); model.cancelRootsDrag()
    XCTAssertEqual(model.actionPreview,klein); XCTAssertFalse(model.busy)
    let calls = await transport.totalCount(); XCTAssertEqual(calls,0)
    model.cancelKleinDrag(); XCTAssertNil(model.actionPreview)
  }

  func testHoverInspectionHasIndependentLeanProvenanceAndCache() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    let selected = model.selected, revision = model.sceneRevision
    model.hover([1,0,1]); await model.waitForHover()
    XCTAssertEqual(model.hoverInspection?.displayPolynomial,"x² + 1")
    XCTAssertEqual(model.hoverInspection?.delta,-4); XCTAssertEqual(model.hoverStatus,"Exact Lean inspection")
    XCTAssertEqual(model.selected,selected); XCTAssertEqual(model.sceneRevision,revision); XCTAssertFalse(model.busy)
    let before = await transport.count(operation:"inspect")
    model.hover(nil); model.hover([1,0,1]); await model.waitForHover()
    let after = await transport.count(operation:"inspect"); XCTAssertEqual(after,before)
    XCTAssertEqual(model.polynomialLabel(for:[1,0,1]),"x² + 1")
    model.hover([13,20,34]); XCTAssertNil(model.hoveredPoint,"Hidden forms cannot become a root hover target")
    XCTAssertNil(model.hoverInspection)
  }

  func testPairLabelsAreAcceptedTogetherAndMalformedSecondaryInspectionRollsBack() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([1,0,1]); await model.waitForPending()
    await transport.hold()
    model.select([1,0,1],pair:[1,1,1])
    let first = try await transport.waitForHeld(1); try await transport.reply(first[0])
    let both = try await transport.waitForHeld(2)
    XCTAssertNil(model.pairedInspection); XCTAssertNil(model.displayedPair)
    try await transport.reply(both[1],corrupt:.wrongGeometry); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertNil(model.pairedInspection); XCTAssertNil(model.displayedPair)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertNil(model.plane)
    let goodTransport = PolynomialTransport(fixture), good = self.model(fixture,goodTransport)
    good.select([1,0,1],pair:[1,1,1]); await good.waitForPending()
    XCTAssertNil(good.error); XCTAssertEqual(good.pairedInspection?.point,[1,1,1])
    XCTAssertEqual(good.polynomialLabel(for:[1,0,1]),"x² + 1")
    XCTAssertEqual(good.polynomialLabel(for:[1,1,1]),"x² + x + 1")
    good.hover(nil); XCTAssertEqual(good.polynomialLabel(for:[1,1,1]),"x² + x + 1")
    good.select([1,0,1]); await good.waitForPending(); XCTAssertNil(good.pairedInspection)
  }

  func testLateOrMalformedHoverNeverChangesSelectionOrCurrentHover() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture), model = model(fixture,transport)
    await transport.hold()
    model.hover([1,0,1]); let first = try await transport.waitForHeld(1)
    model.hover([-1,1,-2]); let both = try await transport.waitForHeld(2)
    try await transport.reply(both[1]); await model.waitForHover()
    XCTAssertEqual(model.hoverInspection?.point,[-1,1,-2])
    try await transport.reply(first[0]); await Task.yield()
    XCTAssertEqual(model.hoverInspection?.point,[-1,1,-2]); XCTAssertEqual(model.selected,[1,-1,2])
    model.hover([1,0,-1]); let third = try await transport.waitForHeld(3)
    try await transport.reply(third[2],corrupt:.wrongGeometry); await model.waitForHover()
    XCTAssertNil(model.hoverInspection); XCTAssertTrue(model.hoverStatus.contains("unavailable"))
    XCTAssertEqual(model.selected,[1,-1,2]); XCTAssertNil(model.error)
    model.hover(nil); XCTAssertNil(model.hoveredPoint); XCTAssertEqual(model.hoverStatus,"")
  }

  func testSpacedPolynomialTypographyPreservesLeadingSignAndRawLeanLabel() throws {
    for (raw,shown) in [("x²−x+2","x² − x + 2"),("−x²+x−2","−x² + x − 2"),
      ("2x²+2","2x² + 2"),("−1","−1"),("x","x"),("0","0"),("x² − x + 2","x² − x + 2")] {
      XCTAssertEqual(PolynomialLabels.spaced(raw),shown)
    }
    let fixture = try PolynomialFixtures()
    let detail = try JSONDecoder().decode(PolynomialInspection.self,from:fixture.initial)
    XCTAssertEqual(detail.polynomial,"x²−x+2"); XCTAssertEqual(detail.displayPolynomial,"x² − x + 2")
  }

  func testExpandedExactIdentityAndPlaneBoundsStaySeparateFromCloudRadius() async throws {
    let fixture = try PolynomialFixtures()
    func response(_ name: String) throws -> Data {
      for data in fixture.polar {
        let item = try polynomialObject(data)
        if item["name"] as? String == name { return try JSONSerialization.data(withJSONObject:XCTUnwrap(item["response"])) }
      }
      throw URLError(.fileDoesNotExist)
    }
    for name in ["inspect-T4-source","inspect-identity-bound-positive","inspect-identity-bound-negative"] {
      XCTAssertTrue(try JSONDecoder().decode(PolynomialInspection.self,from:response(name)).isValid,name)
    }
    let extreme = try JSONDecoder().decode(PolynomialAction.self,from:response("transform-safe-integer-edge"))
    XCTAssertTrue(extreme.isValid); XCTAssertEqual(extreme.point,[1024,-1024,1024])
    XCTAssertTrue((extreme.imageNumerator+extreme.xyzNumerator).allSatisfy { abs($0) <= 6_144_000_000_000_000 })
    let plane = try JSONDecoder().decode(PolynomialPlane.self,from:response("pair-large-normal"))
    XCTAssertTrue(plane.isValidPair); XCTAssertEqual(plane.normal,[257617,1052910,150135])
    let transport = PolynomialTransport(fixture), model = model(fixture,transport)
    model.select([957,361,180],pair:[983,640,735]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.plane?.normal,plane.normal)
    XCTAssertFalse(model.selectionShown); XCTAssertEqual(model.points.count,480)
    var abc = try XCTUnwrap(polynomialObject(fixture.cloud)["abc"] as? [Int]); abc[0] = 1024
    let badCloud = try JSONDecoder().decode(PolynomialCloud.self,from:changedPolynomial(fixture.cloud,field:"abc",value:abc))
    XCTAssertFalse(badCloud.isValid,"The expanded identity domain must not silently expand the cloud protocol.")
  }

  func testActualLeanCloudMatchesCanonicalOrderAndSignedPopulation() throws {
    let fixture = try PolynomialFixtures()
    let header = try JSONDecoder().decode(PolynomialHeader.self, from: fixture.cloud)
    let cloud = try JSONDecoder().decode(PolynomialCloud.self, from: fixture.cloud)
    XCTAssertTrue(header.ok && header.recognized)
    XCTAssertTrue(cloud.isValid)
    XCTAssertEqual(cloud.radius, 6); XCTAssertFalse(cloud.upperOnly)
    XCTAssertEqual(cloud.count, 480); XCTAssertEqual(cloud.total, 480)
    XCTAssertEqual(cloud.offset, 0); XCTAssertNil(cloud.nextOffset)
    XCTAssertEqual((0...3).map { kind in cloud.kind.filter { $0 == kind }.count }, [24,346,55,55])
    XCTAssertEqual(cloud.points.first?.abc, [-4,-1,-1]); XCTAssertEqual(cloud.points.last?.abc, [4,1,1])
    XCTAssertEqual(Set(cloud.points.map(\.id)).count, cloud.count)
    var bytes = Data()
    for value in cloud.abc {
      var little = Int16(value).littleEndian
      withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
    }
    let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(hash, "3a8951bf38c454b4730f2147b1de7de050401880fd8406fb9b6a97b09aa65343")
    for p in cloud.points {
      XCTAssertEqual(p.xyz, [-p.abc[1], p.abc[0]+p.abc[2], p.abc[2]-p.abc[0]])
      XCTAssertEqual(p.vector, SIMD3(Float(p.xyz[0]), Float(p.xyz[1]), Float(p.xyz[2])))
    }
  }

  func testActualLeanInspectionAndAppearanceMatchPinnedCanonicalCases() throws {
    let fixture = try PolynomialFixtures()
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let contract = try polynomialObject(Data(contentsOf: root.appendingPathComponent("fixtures/polynomial-contract.json")))
    let expected = try XCTUnwrap(contract["pointCases"] as? [[String: Any]])
    for reference in expected where reference["id"] as? String != "zero_excluded" {
      let name = try XCTUnwrap(reference["id"] as? String)
      let data = try XCTUnwrap(fixture.cases[name])
      let detail = try JSONDecoder().decode(PolynomialInspection.self, from: data)
      XCTAssertTrue(detail.isValid, name)
      XCTAssertEqual(detail.point, reference["abc"] as? [Int], name)
      XCTAssertEqual(detail.xyz, reference["displayXYZ"] as? [Int], name)
      XCTAssertEqual(detail.polynomial, reference["polynomial"] as? String, name)
      XCTAssertEqual(detail.delta, reference["discriminant"] as? Int, name)
      XCTAssertEqual(detail.kind, reference["kind"] as? String, name)
      XCTAssertEqual(detail.divisor, reference["divisor"] as? Int, name)
      XCTAssertEqual(detail.positiveRepresentative, reference["positiveRepresentative"] as? [Int], name)
      let appearance = try XCTUnwrap(reference["appearance"] as? [String: Any])
      let point = PolynomialPoint(abc: detail.point, xyz: detail.xyz, delta: detail.delta,
        kind: try XCTUnwrap(reference["kindCode"] as? Int), divisor: detail.divisor, onPlane: false, necklace: false)
      for lower in [false, true] {
        let rgb = PolynomialAppearance.color(point, colorLower: lower) * 255
        let channels = [rgb.x, rgb.y, rgb.z].map { Int($0.rounded(.toNearestOrAwayFromZero)) }
        XCTAssertEqual(channels, appearance[lower ? "symmetricViridisRGB8" : "viridisRGB8"] as? [Int], name)
        let expectedRadius = try XCTUnwrap(appearance[lower ? "symmetricOverviewRadiusFactor" : "overviewRadiusFactor"] as? Double)
        XCTAssertEqual(Double(PolynomialAppearance.radiusFactor(point, colorLower: lower, atOrigin: false)), expectedRadius, accuracy: 1e-6, name)
      }
      let originRadius = try XCTUnwrap(appearance["originRadiusFactor"] as? Double)
      XCTAssertEqual(Double(PolynomialAppearance.radiusFactor(point, colorLower: false, atOrigin: true)), originRadius, accuracy: 1e-6, name)
    }
  }

  func testActualPlaneLabelsAndMembersAreAcceptedWithoutSwiftPlaneRecomputation() throws {
    let fixture = try PolynomialFixtures()
    let pair = try JSONDecoder().decode(PolynomialPlane.self, from: XCTUnwrap(fixture.cases["pair"]))
    XCTAssertTrue(pair.isValid)
    XCTAssertTrue(pair.isValidPair)
    let ordinary = try JSONDecoder().decode(PolynomialPlane.self, from: XCTUnwrap(fixture.cases["plane"]))
    XCTAssertTrue(ordinary.isValid)
    XCTAssertFalse(ordinary.isValidPair)
    XCTAssertEqual(pair.normal, [1,0,-1]); XCTAssertEqual(pair.planeCoefficients, [2,0,-2])
    XCTAssertEqual(pair.cartesianNormal, [0,0,-2]); XCTAssertEqual(pair.equation, "2a −2c = 0")
    XCTAssertEqual(pair.endpoints.map(\.label), ["-1","1"])
    XCTAssertEqual(pair.endpoints.map(\.displayValue), [-1,1])
    XCTAssertTrue(pair.checks.values.allSatisfy { $0 })
    let members = try polynomialObject(XCTUnwrap(fixture.cases["members"]))
    XCTAssertEqual(members["count"] as? Int, 22)
    XCTAssertEqual((members["indices"] as? [Int])?.count, 22)
  }

  func testCloudRejectsMalformedArraysCoordinatesPaginationAndKinds() throws {
    let fixture = try PolynomialFixtures()
    var xyz = try XCTUnwrap(polynomialObject(fixture.cloud)["xyz"] as? [Int]); xyz[0] += 1
    var swappedSigns = try XCTUnwrap(polynomialObject(fixture.cloud)["kind"] as? [Int])
    if let upper = swappedSigns.firstIndex(of: 2) { swappedSigns[upper] = 3 }
    let corruptions: [(String, Any)] = [
      ("xyz", xyz), ("abc", [1,0,1]), ("count", 481), ("kind", Array(repeating: 0, count: 480)),
      ("divisor", Array(repeating: 0, count: 480)), ("nextOffset", 1), ("offset", Int.max), ("radius", 97),
      ("kind", swappedSigns),
    ]
    for (field, value) in corruptions {
      let decoded = try JSONDecoder().decode(PolynomialCloud.self, from: changedPolynomial(fixture.cloud, field: field, value: value))
      XCTAssertFalse(decoded.isValid, "Accepted malformed \(field)")
    }
    var missing = try polynomialObject(fixture.cloud); missing.removeValue(forKey: "xyz")
    XCTAssertThrowsError(try JSONDecoder().decode(PolynomialCloud.self, from: JSONSerialization.data(withJSONObject: missing)))
  }

  func testInspectionRejectsMalformedPointCoordinatesAndExactDescriptors() throws {
    let fixture = try PolynomialFixtures()
    let corruptions: [(String, Any)] = [
      ("point", [0,0,0]), ("point", [1,0]), ("point", [1025,0,1]), ("xyz", [0,0,0]),
      ("primitive", [1,0]), ("positiveRepresentative", [1,0]), ("kind", "exterior"), ("divisor", 0),
      ("projection", [[0,1],[4,0],[0,1]]),
      ("root", ["real":[0,0], "imaginary":["radicand":4,"denominator":2]]),
    ]
    for (field, value) in corruptions {
      let decoded = try JSONDecoder().decode(PolynomialInspection.self, from: changedPolynomial(fixture.initial, field: field, value: value))
      XCTAssertFalse(decoded.isValid, "Accepted malformed \(field)")
    }
  }

  func testPlaneRejectsInconsistentCoordinateMapFalseChecksAndBadEndpoints() throws {
    let fixture = try PolynomialFixtures(), pair = try XCTUnwrap(fixture.cases["pair"])
    let corruptions: [(String, Any)] = [
      ("normal", [0,0,0]), ("normal", [Int.max,0,-1]), ("planeCoefficients", [0,0,0]),
      ("cartesianNormal", [0,0,2]), ("checks", ["exterior":false]), ("endpoints", []),
      ("checks", [String: Bool]()), ("checks", ["unrelated":true]),
      ("checks", ["exterior":true]), ("checks", ["primitive":true]),
      ("checks", ["exterior":true,"primitive":false]),
      ("endpoints", [["kind":"rational","label":"bad","numerator":1,"denominator":0],
                     ["kind":"infinity","label":"∞"]]),
    ]
    for (field, value) in corruptions {
      let decoded = try JSONDecoder().decode(PolynomialPlane.self, from: changedPolynomial(pair, field: field, value: value))
      XCTAssertFalse(decoded.isValid, "Accepted malformed \(field)")
    }
  }

  func testBundledInitializationAndLivePairUseActualLeanMembership() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    XCTAssertEqual(model.points.count, 480); XCTAssertEqual(model.inspection?.point, [1,-1,2])
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.polynomial, "x²−x+2")
    XCTAssertEqual(model.source, "Bundled Lean export"); XCTAssertFalse(model.busy)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.plane?.normal, [1,0,-1])
    let members = try polynomialObject(XCTUnwrap(fixture.cases["members"]))
    let indices = try XCTUnwrap(members["indices"] as? [Int])
    XCTAssertEqual(model.points.indices.filter { model.points[$0].onPlane }, indices)
    XCTAssertEqual(model.points.indices.filter { model.points[$0].necklace }, indices)
    XCTAssertEqual(model.source, "Lean response from Mac")
    XCTAssertTrue(model.status.contains("Live Lean"))
  }

  func testLateInspectionCannotReplaceNewSelectionOrAcceptedScene() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    await transport.hold()
    model.select([1,0,1]); let first = try await transport.waitForHeld(1)
    model.select([1,1,1]); let both = try await transport.waitForHeld(2)
    try await transport.reply(both[1]); await model.waitForPending()
    let revision = model.sceneRevision
    try await transport.reply(first[0])
    await Task.yield(); await Task.yield()
    XCTAssertEqual(model.selected, [1,1,1]); XCTAssertEqual(model.inspection?.point, [1,1,1])
    XCTAssertEqual(model.sceneRevision, revision); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
  }

  func testFailureKeepsAcceptedSceneAndItsProvenance() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.refresh(); await model.waitForPending()
    let accepted = model.points, revision = model.sceneRevision
    await transport.hold(); model.select([1,0,1])
    let calls = try await transport.waitForHeld(1)
    try await transport.fail(calls[0]); await model.waitForPending()
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
    XCTAssertEqual(model.points, accepted); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertEqual(model.source, "Lean response from Mac")
    XCTAssertTrue(model.status.contains("Previous accepted scene")); XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
  }

  func testInvalidBridgeInvalidatesAlreadyPendingResponse() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    await transport.hold(); model.select([1,0,1])
    let calls = try await transport.waitForHeld(1)
    model.server = "not a URL"; model.refresh(); await model.waitForPending()
    try await transport.reply(calls[0]); await Task.yield(); await Task.yield()
    XCTAssertEqual(model.inspection?.point, [1,-1,2]); XCTAssertEqual(model.sceneRevision, 0)
    XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.source, "Bundled Lean export")
  }

  func testTransportRejectsWrongSchemaRevisionSequenceFalseOKAndGeometry() async throws {
    for corruption: PolynomialTransport.Corruption in [.wrongID,.falseOK,.wrongSchema,.wrongCommit,.wrongGeometry] {
      let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
      let model = model(fixture, transport)
      await transport.hold(); model.select([1,0,1])
      let calls = try await transport.waitForHeld(1)
      try await transport.reply(calls[0], corrupt: corruption); await model.waitForPending()
      XCTAssertEqual(model.inspection?.point, [1,-1,2]); XCTAssertEqual(model.sceneRevision, 0)
      XCTAssertEqual(model.source, "Bundled Lean export")
      XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    }
  }

  func testNextFollowsCanonicalSequenceWrapsAndPreservesHiddenSelectionAndPlacement() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let sequence = [[1,-1,2],[2,-2,4],[2,1,1],[1,0,1],[3,2,2],[-1,1,-2],[1,2,1],[1,3,1]]
    XCTAssertEqual(model.selected, sequence[0])
    let placement = PolynomialPlacement.inhabit(xyz: try XCTUnwrap(model.inspection).xyz)
    model.place(placement)
    for expected in Array(sequence.dropFirst()) + [sequence[0]] {
      model.nextCoefficient(); await model.waitForPending()
      XCTAssertNil(model.error, "Next failed for \(expected)")
      XCTAssertEqual(model.selected, expected); XCTAssertEqual(model.inspection?.point, expected)
      XCTAssertEqual(model.placement, placement)
      XCTAssertNil(model.paired); XCTAssertEqual(model.displayedRadius, 6)
      if expected == [2,-2,4] {
        XCTAssertFalse(model.points.contains { $0.abc == expected })
        XCTAssertFalse(model.selectionShown)
        XCTAssertEqual(model.inspection?.polynomial, "2x²−2x+4")
      } else {
        XCTAssertTrue(model.selectionShown)
      }
      if expected == [1,3,1] {
        XCTAssertEqual(model.plane?.normal, expected)
        let members = try polynomialObject(XCTUnwrap(fixture.cases["members-exterior"]))
        XCTAssertEqual(model.points.indices.filter { model.points[$0].onPlane }, members["indices"] as? [Int])
      } else {
        XCTAssertNil(model.plane)
      }
    }
  }

  func testNextDropsThePreviousPairAndPlaneMembers() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertEqual(model.paired, [1,1,1]); XCTAssertNotNil(model.plane)
    XCTAssertTrue(model.points.contains { $0.onPlane })
    model.nextCoefficient(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.selected, [3,2,2])
    XCTAssertEqual(model.inspection?.point, [3,2,2]); XCTAssertNil(model.paired); XCTAssertNil(model.plane)
    XCTAssertFalse(model.points.contains { $0.onPlane || $0.necklace })
  }

  func testResetRestoresCanonicalSceneAndPreservesPaletteSizeAndPlaneFade() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertNotNil(model.plane)
    model.radius = 12; model.upperOnly = true; model.colorLower = true
    model.showProjection = true; model.viewpoint = 2; model.place(.origin(lower: true))
    model.palette = "reference"; model.starSize = 2; model.planeFocus = true; model.showCone = false
    model.snapOnRelease = true
    model.reset(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
    XCTAssertEqual(model.inspection?.polynomial, "x²−x+2")
    XCTAssertEqual(model.radius, 6); XCTAssertEqual(model.displayedRadius, 6)
    XCTAssertEqual(model.points.count, 480); XCTAssertFalse(model.upperOnly)
    XCTAssertFalse(model.colorLower); XCTAssertFalse(model.showProjection); XCTAssertEqual(model.viewpoint, 0)
    XCTAssertEqual(model.palette, "reference"); XCTAssertEqual(model.starSize, 2)
    XCTAssertTrue(model.planeFocus); XCTAssertTrue(model.showCone)
    XCTAssertFalse(model.snapOnRelease)
    XCTAssertEqual(model.placement, .overview); XCTAssertNil(model.paired); XCTAssertNil(model.plane)
    XCTAssertFalse(model.points.contains { $0.onPlane || $0.necklace })
  }

  func testEntryUsesAcceptedCloudAndRejectsHiddenNextMultipleWithoutChangingSelection() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    // A requested larger crop is not an accepted larger cloud.
    model.radius = 12
    for point in [[2,-2,4],[0,0,0],[97,0,1],[1,2]] {
      model.enter(point)
      XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
      XCTAssertEqual(model.sceneRevision, 0); XCTAssertFalse(model.busy); XCTAssertNotNil(model.error)
    }
    model.radius = 6
    model.nextCoefficient(); await model.waitForPending()
    XCTAssertEqual(model.selected, [2,-2,4]); XCTAssertFalse(model.selectionShown)
    let revision = model.sceneRevision
    model.enter([2,-2,4])
    XCTAssertNotNil(model.error); XCTAssertEqual(model.selected, [2,-2,4])
    XCTAssertEqual(model.inspection?.point, [2,-2,4]); XCTAssertEqual(model.sceneRevision, revision)
    model.enter([1,0,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertTrue(model.selectionShown)
    model.enter([1,1,1], asPair: true); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.paired, [1,1,1]); XCTAssertNotNil(model.plane)
    let pairedRevision = model.sceneRevision
    model.enter([2,-2,4], asPair: true)
    XCTAssertNotNil(model.error); XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.sceneRevision, pairedRevision)
  }

  func testPendingAndFailedPairKeepOnlyAcceptedPairVisible() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertEqual(model.displayedPair, [1,1,1])
    let accepted = model.points, revision = model.sceneRevision
    await transport.hold()
    model.select([1,0,1], pair: [3,2,2])
    let calls = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy); XCTAssertEqual(model.paired, [3,2,2])
    XCTAssertEqual(model.displayedPair, [1,1,1]); XCTAssertEqual(model.points, accepted)
    try await transport.fail(calls[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.paired, [1,1,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertEqual(model.plane?.normal, [1,0,-1]); XCTAssertEqual(model.points, accepted)
  }

  func testPairResponseRequiresEveryIncidenceCheckAndPreservesAcceptedSceneWhenMissing() async throws {
    let fixture = try PolynomialFixtures()
    for omitted in ["firstOnPlane", "secondOnPlane", "rawFirstOnPlane", "rawSecondOnPlane"] {
      // Immediate fixture transport keeps a missed rejection observable as an assertion failure,
      // rather than leaving the model suspended on a subsequent membership request.
      let model = PolynomialModel(cloudData: fixture.cloud, inspectionData: fixture.initial, transport: { request in
        let input = try polynomialObject(XCTUnwrap(request.httpBody))
        var output = try polynomialObject(fixture.response(for: input))
        output["id"] = input["id"]
        if input["op"] as? String == "pair" {
          var checks = try XCTUnwrap(output["checks"] as? [String: Bool])
          checks.removeValue(forKey: omitted)
          output["checks"] = checks
        }
        let response = try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200,
          httpVersion: nil, headerFields: nil))
        return (try JSONSerialization.data(withJSONObject: output), response)
      })
      let accepted = model.points, revision = model.sceneRevision
      model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
      XCTAssertNotNil(model.error, "Accepted pair response without \(omitted)")
      XCTAssertFalse(model.busy)
      XCTAssertEqual(model.points, accepted); XCTAssertEqual(model.sceneRevision, revision)
      XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
      XCTAssertNil(model.paired); XCTAssertNil(model.displayedPair); XCTAssertNil(model.plane)
      XCTAssertEqual(model.source, "Bundled Lean export")
    }
  }

  func testBaselineIdentityAndInvalidActionInputDoNotRequestATransform() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.refresh(); await model.waitForPending()
    XCTAssertNil(model.action); XCTAssertEqual(model.actionMatrix, [1,0,0,1])
    XCTAssertEqual(model.displayActionRows, [1,0,0,0,1,0,0,0,1])
    let revision = model.sceneRevision
    for invalid in [[1,0,0], [1,0,0,-1], [1,1,1,1], [Int.max,0,0,1]] {
      model.requestAction(invalid)
      XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
      XCTAssertNil(model.action); XCTAssertEqual(model.actionMatrix, [1,0,0,1])
      XCTAssertEqual(model.sceneRevision, revision)
    }
    let count = await transport.count(operation: "transform")
    XCTAssertEqual(count, 0)
  }

  func testPendingAndFailedActionKeepAcceptedGeometryReceiptAndRequestedMatrixRestores() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let translation = [1,1,0,1], inversion = [0,-1,1,0]
    model.requestAction(translation); await model.waitForPending()
    XCTAssertNil(model.error)
    let accepted = try XCTUnwrap(model.action), points = model.points
    let rows = model.displayActionRows, revision = model.sceneRevision
    await transport.hold(operation: "transform")
    model.requestAction(inversion)
    let held = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy); XCTAssertEqual(model.actionMatrix, inversion)
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.displayActionRows, rows)
    XCTAssertEqual(model.points, points); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertTrue(model.actionStatus.contains("Waiting for Lean"))
    try await transport.fail(held[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.actionMatrix, translation); XCTAssertEqual(model.action?.id, accepted.id)
    XCTAssertEqual(model.displayActionRows, rows); XCTAssertEqual(model.points, points)
    XCTAssertEqual(model.sceneRevision, revision); XCTAssertEqual(model.source, "Lean response from Mac")
    XCTAssertTrue(model.status.contains("Previous accepted scene"))
  }

  func testLateActionCannotReplaceMoreRecentAcceptedTransform() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.requestAction([1,1,0,1]); await model.waitForPending()
    XCTAssertNil(model.error)
    await transport.hold(operation: "transform")
    model.requestAction([0,-1,1,0]); let first = try await transport.waitForHeld(1)
    model.requestAction([1,-1,0,1]); let both = try await transport.waitForHeld(2)
    try await transport.reply(both[1]); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
    XCTAssertEqual(accepted.matrix, [1,-1,0,1]); XCTAssertEqual(accepted.image, [1,1,2])
    try await transport.reply(first[0]); await Task.yield(); await Task.yield()
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertEqual(model.actionMatrix, [1,-1,0,1]); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
  }

  func testTransformedReadoutsKeepExactBaseAndTrackAcceptedPreviewAndFailureStates() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    XCTAssertFalse(model.rootReadout.hasPrefix("Base "))
    XCTAssertEqual(model.planeReadout,"2a −2c = 0 · -1 and 1")
    model.requestAction([3,1,1,2]); await model.waitForPending()
    XCTAssertTrue(model.rootReadout.hasPrefix("Base "))
    XCTAssertTrue(model.rootReadout.hasSuffix("shown ≈ 1.000 + 1.000i"),model.rootReadout)
    XCTAssertEqual(model.planeReadout,"Base 2a −2c = 0 · -1 and 1 · shown ≈ -2.000 and 1.333")
    let root = model.rootReadout, plane = model.planeReadout
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
    model.place(.origin(lower:false)); model.beginActionDrag(at:[0,0]); model.updateActionDrag(to:[0.1,0],force:true)
    XCTAssertTrue(model.rootReadout.contains("preview ≈")); XCTAssertTrue(model.planeReadout.contains("preview ≈"))
    model.cancelActionDrag()
    XCTAssertEqual(model.rootReadout,root); XCTAssertEqual(model.planeReadout,plane)
    await transport.hold(operation:"transform")
    model.requestAction([0,-1,1,0]); let held = try await transport.waitForHeld(1)
    XCTAssertEqual(model.rootReadout,root); XCTAssertEqual(model.planeReadout,plane)
    try await transport.fail(held[0]); await model.waitForPending()
    XCTAssertEqual(model.rootReadout,root); XCTAssertEqual(model.planeReadout,plane)
    XCTAssertEqual(model.inspection?.point,[1,0,1]); XCTAssertEqual(model.displayedPair,[1,1,1])
  }

  func testPolarSnapAbsorbsActualLeanPairAndRecordedSourceOutsideCloudRadius() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture,transport)
    model.select([1,0,1],pair:[1,1,1]); await model.waitForPending()
    model.requestAction([50,18,0,5]); await model.waitForPending()
    XCTAssertNil(model.error)
    XCTAssertTrue(model.rootReadout.hasSuffix("shown ≈ 3.600 + 10.000i"),model.rootReadout)
    XCTAssertTrue(model.planeReadout.hasSuffix("shown ≈ -6.400 and 13.600"),model.planeReadout)
    model.snapAction(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.inspection?.point,[1,-8,17])
    XCTAssertEqual(model.displayedPair,[1,-7,13]); XCTAssertTrue(model.plane?.isValidPair == true)
    XCTAssertEqual(model.action?.matrix,[1,0,0,1]); XCTAssertFalse(model.rootReadout.hasPrefix("Base "))
    model.requestAction([1,0,0,1]); await model.waitForPending()
    XCTAssertEqual(model.inspection?.point,[1,-8,17]); XCTAssertEqual(model.displayedPair,[1,-7,13])

    model.select([13,20,34]); await model.waitForPending()
    model.requestAction([50,18,0,5]); await model.waitForPending()
    XCTAssertNil(model.error)
    model.snapAction(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.inspection?.point,[13,-84,162])
    XCTAssertEqual(model.action?.matrix,[1,0,0,1]); XCTAssertFalse(model.selectionShown)
    XCTAssertEqual(model.inspection?.delta,-1368); XCTAssertNil(model.displayedPair)
    model.requestAction([1,0,0,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.inspection?.point,[13,-84,162])
  }

  func testNewSelectionRefreshesActionReceiptAtSameMatrixAndCancelsPreviewAtomically() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let translation = [1,1,0,1]
    model.requestAction(translation); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
    model.place(.origin(lower: false)); model.beginActionDrag(at: [0,0])
    model.updateActionDrag(to: [0,0.6]); XCTAssertNotNil(model.actionPreview)
    await transport.hold(operation: "transform")
    model.select([1,0,1]); XCTAssertNil(model.actionPreview)
    let held = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy); XCTAssertEqual(model.selected, [1,0,1])
    XCTAssertEqual(model.inspection?.point, [1,-1,2]); XCTAssertEqual(model.action?.id, accepted.id)
    XCTAssertEqual(model.action?.point, [1,-1,2]); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertEqual(model.displayActionRows, accepted.coefficientRowsApprox)
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.actionMatrix, translation)
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.action?.point, [1,0,1])
    XCTAssertEqual(model.action?.image, [1,-2,2]); XCTAssertEqual(model.action?.delta, model.inspection?.delta)
    XCTAssertNotEqual(model.action?.id, accepted.id); XCTAssertEqual(model.sceneRevision, revision + 1)
  }

  func testCancelledPreviewAndPlacementChangeSendNoTransformAndRestoreAcceptedRows() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.requestAction([1,1,0,1]); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), rows = model.displayActionRows
    let revision = model.sceneRevision, before = await transport.count(operation: "transform")
    // These exercise model methods only; they do not claim a simulator or physical gesture passed.
    model.beginActionDrag(at: [0,0]); XCTAssertNil(model.actionPreview, "Overview must not start a transform preview")
    model.place(.origin(lower: false)); model.beginActionDrag(at: [0,0])
    model.updateActionDrag(to: [0,0.6])
    XCTAssertNotNil(model.actionPreview); XCTAssertNotEqual(model.displayActionRows, rows)
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.sceneRevision, revision)
    XCTAssertTrue(model.actionStatus.contains("Approximate drag preview"))
    model.cancelActionDrag(); model.commitActionDrag()
    XCTAssertNil(model.actionPreview); XCTAssertEqual(model.displayActionRows, rows)
    model.beginActionDrag(at: [0,0]); model.updateActionDrag(to: [0,0.6])
    model.place(.overview); model.commitActionDrag()
    XCTAssertNil(model.actionPreview); XCTAssertEqual(model.displayActionRows, rows)
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, accepted.matrix)
    XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    let after = await transport.count(operation: "transform")
    XCTAssertEqual(after, before)
  }

  func testCommittedPreviewWaitsForExactLeanReceiptBeforeChangingAcceptedRows() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let points = model.points, baseRows = model.displayActionRows
    model.place(.origin(lower: false)); model.beginActionDrag(at: [0,0])
    // The canonical vertical transvection i → 4i quantizes to the declared matrix [4,0,0,1].
    model.updateActionDrag(to: [0,15.0/17.0])
    XCTAssertEqual(model.actionPreview?.commitMatrix(ifRevision: model.sceneRevision), [4,0,0,1])
    XCTAssertNotEqual(model.displayActionRows, baseRows)
    await transport.hold(operation: "transform")
    model.commitActionDrag()
    let held = try await transport.waitForHeld(1)
    XCTAssertNil(model.actionPreview); XCTAssertNil(model.action); XCTAssertTrue(model.busy)
    XCTAssertEqual(model.actionMatrix, [4,0,0,1]); XCTAssertEqual(model.displayActionRows, baseRows)
    XCTAssertEqual(model.points, points)
    model.beginActionDrag(at: [0,0]); XCTAssertNil(model.actionPreview, "Pending requests must not start a preview")
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    let accepted = try XCTUnwrap(model.action)
    XCTAssertTrue(accepted.isValid); XCTAssertEqual(accepted.matrix, [4,0,0,1])
    XCTAssertEqual(accepted.denominator, 4); XCTAssertEqual(accepted.imageNumerator, [1,-4,32])
    XCTAssertEqual(model.displayActionRows, accepted.coefficientRowsApprox)
    XCTAssertEqual(model.points, points, "Signed base identities stay unchanged; rendering applies accepted rows")
    let count = await transport.count(operation: "transform")
    XCTAssertEqual(count, 1)
  }

  func testResetRequestsIdentityAndKeepsAcceptedActionUntilReceiptWhilePreservingAppearancePreferences() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.requestAction([1,1,0,1]); await model.waitForPending()
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertNotNil(model.plane)
    let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
    model.palette = "reference"; model.starSize = 2; model.planeFocus = true
    model.place(.origin(lower: true)); model.beginActionDrag(at: [0,0])
    await transport.hold(operation: "transform")
    model.reset()
    let held = try await transport.waitForHeld(1)
    XCTAssertNil(model.actionPreview); XCTAssertEqual(model.placement, .overview)
    XCTAssertEqual(model.actionMatrix, [1,0,0,1]); XCTAssertEqual(model.action?.id, accepted.id)
    XCTAssertEqual(model.displayActionRows, accepted.coefficientRowsApprox)
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertEqual(model.sceneRevision, revision)
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.action?.matrix, [1,0,0,1]); XCTAssertEqual(model.action?.point, [1,-1,2])
    XCTAssertEqual(model.action?.image, [1,-1,2]); XCTAssertEqual(model.selected, [1,-1,2])
    XCTAssertEqual(model.displayActionRows, [1,0,0,0,1,0,0,0,1])
    XCTAssertEqual(model.palette, "reference"); XCTAssertEqual(model.starSize, 2); XCTAssertTrue(model.planeFocus)
    XCTAssertEqual(model.radius, 6); XCTAssertNil(model.plane); XCTAssertNil(model.displayedPair)
    XCTAssertEqual(model.sceneRevision, revision + 1)
  }

  func testMalformedActionReceiptCannotReplaceAcceptedTransform() async throws {
    let fixture = try PolynomialFixtures()
    for corruption: PolynomialTransport.Corruption in [.wrongID,.falseOK,.wrongSchema,.wrongCommit,
      .wrongActionCommit,.missingActionCheck,.wrongActionPoint] {
      let transport = PolynomialTransport(fixture), model = model(fixture, transport)
      model.requestAction([1,1,0,1]); await model.waitForPending()
      let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
      await transport.hold(operation: "transform")
      model.requestAction([0,-1,1,0]); let held = try await transport.waitForHeld(1)
      try await transport.reply(held[0], corrupt: corruption); await model.waitForPending()
      XCTAssertNotNil(model.error, "Accepted malformed action \(corruption)"); XCTAssertFalse(model.busy)
      XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, accepted.matrix)
      XCTAssertEqual(model.displayActionRows, accepted.coefficientRowsApprox)
      XCTAssertEqual(model.inspection?.point, accepted.point); XCTAssertEqual(model.sceneRevision, revision)
    }
  }

  func testIntegralAbsorptionCommitsBothSignedSelectionsPlaneMembersAndIdentityTogether() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let translation = [1,1,0,1]
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    model.requestAction(translation); await model.waitForPending()
    XCTAssertNil(model.error)
    let accepted = try XCTUnwrap(model.action), points = model.points, revision = model.sceneRevision
    await transport.hold(operation: "members")
    model.absorbAction(translation)
    let held = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, translation)
    XCTAssertEqual(model.plane?.normal, [1,0,-1]); XCTAssertEqual(model.points, points)
    XCTAssertEqual(model.sceneRevision, revision)
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected, [1,-2,2]); XCTAssertEqual(model.paired, [1,-1,1])
    XCTAssertEqual(model.inspection?.point, [1,-2,2]); XCTAssertEqual(model.displayedPair, [1,-1,1])
    XCTAssertEqual(model.action?.matrix, [1,0,0,1]); XCTAssertEqual(model.actionMatrix, [1,0,0,1])
    XCTAssertEqual(model.action?.point, [1,-2,2]); XCTAssertEqual(model.action?.image, [1,-2,2])
    XCTAssertEqual(model.plane?.normal, [1,-2,0]); XCTAssertTrue(model.plane?.isValidPair == true)
    XCTAssertEqual(model.plane?.endpoints.map(\.label), ["0","2"])
    let members = try polynomialObject(XCTUnwrap(fixture.cases["members-pair-T"]))
    XCTAssertEqual(model.points.indices.filter { model.points[$0].onPlane }, members["indices"] as? [Int])
    XCTAssertEqual(model.sceneRevision, revision + 1)
  }

  func testSnapOnReleaseCancellationSendsNoRequestsAndCommitAbsorbsAcceptedPairAtomically() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    XCTAssertNil(model.error)
    model.place(.origin(lower: false)); model.snapOnRelease = true
    let points = model.points, rows = model.displayActionRows, revision = model.sceneRevision
    let requestCount = await transport.totalCount()
    let target = SIMD2<Double>(2.0/3.0,1.0/3.0)

    // Model-event coverage only: a cancelled preview never reaches the bridge.
    model.beginActionDrag(at: [0,0]); model.updateActionDrag(to: target, force: true)
    XCTAssertNotNil(model.actionPreview); XCTAssertNotEqual(model.displayActionRows, rows)
    model.cancelActionDrag(); model.commitActionDrag()
    let afterCancellation = await transport.totalCount()
    XCTAssertEqual(afterCancellation, requestCount)
    XCTAssertNil(model.actionPreview); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
    XCTAssertEqual(model.displayActionRows, rows); XCTAssertEqual(model.points, points)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])

    model.beginActionDrag(at: [0,0]); model.updateActionDrag(to: target, force: true)
    let preview = try XCTUnwrap(model.actionPreview)
    XCTAssertEqual(PolynomialMobius.nearestIntegral(preview.matrix), [1,1,0,1])
    XCTAssertTrue(model.actionStatus.contains("release proposes integer Snap"))
    await transport.hold(operation: "members")
    model.commitActionDrag(); let held = try await transport.waitForHeld(1)
    XCTAssertNil(model.actionPreview); XCTAssertTrue(model.busy)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertNil(model.action); XCTAssertEqual(model.displayActionRows, rows)
    XCTAssertEqual(model.points, points); XCTAssertEqual(model.sceneRevision, revision)
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected, [1,-2,2]); XCTAssertEqual(model.paired, [1,-1,1])
    XCTAssertEqual(model.inspection?.point, [1,-2,2]); XCTAssertEqual(model.displayedPair, [1,-1,1])
    XCTAssertEqual(model.actionMatrix, [1,0,0,1]); XCTAssertEqual(model.action?.matrix, [1,0,0,1])
    XCTAssertEqual(model.action?.point, [1,-2,2]); XCTAssertEqual(model.action?.image, [1,-2,2])
    XCTAssertEqual(model.plane?.normal, [1,-2,0]); XCTAssertTrue(model.plane?.isValidPair == true)
    XCTAssertEqual(model.sceneRevision, revision + 1)
  }

  func testNudgeRequiresOriginFiniteDiskInputAndIdleStateThenAcceptsAnExactLeanSample() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    let points = model.points, rows = model.displayActionRows, revision = model.sceneRevision
    model.nudgeAction([0,0.2])
    let overviewRequests = await transport.totalCount()
    XCTAssertEqual(overviewRequests, 0); XCTAssertNil(model.actionPreview); XCTAssertFalse(model.busy)
    model.place(.origin(lower: false))
    for direction: SIMD2<Double> in [[1,0],[0,1],[.nan,0],[0,.infinity]] {
      model.nudgeAction(direction)
      XCTAssertNil(model.actionPreview); XCTAssertNil(model.action); XCTAssertFalse(model.busy)
    }
    let invalidRequests = await transport.totalCount()
    XCTAssertEqual(invalidRequests, 0)

    await transport.hold(operation: "transform")
    model.nudgeAction([0,0.2]); let held = try await transport.waitForHeld(1)
    XCTAssertTrue(model.busy); XCTAssertNil(model.actionPreview); XCTAssertNil(model.action)
    XCTAssertEqual(model.actionMatrix, [3689,0,0,3012])
    XCTAssertEqual(model.displayActionRows, rows); XCTAssertEqual(model.points, points)
    XCTAssertEqual(model.sceneRevision, revision)
    let pendingRequests = await transport.totalCount()
    model.nudgeAction([0.2,0]); model.setSnapOnRelease(true)
    let afterBusyInputs = await transport.totalCount()
    XCTAssertEqual(afterBusyInputs, pendingRequests); XCTAssertFalse(model.snapOnRelease)
    XCTAssertEqual(model.actionMatrix, [3689,0,0,3012])
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy)
    let accepted = try XCTUnwrap(model.action)
    XCTAssertTrue(accepted.isValid); XCTAssertEqual(accepted.matrix, [3689,0,0,3012])
    XCTAssertEqual(accepted.denominator, 11_111_268)
    XCTAssertEqual(accepted.imageNumerator, [9_072_144,-11_111_268,27_217_442])
    XCTAssertEqual(accepted.delta, -7); XCTAssertNil(accepted.image)
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
    XCTAssertEqual(model.displayActionRows, accepted.coefficientRowsApprox)
    XCTAssertEqual(model.points, points); XCTAssertEqual(model.sceneRevision, revision + 1)
  }

  func testEnablingSnapImmediatelyAbsorbsAcceptedPairWhileDisablingSendsNoRequest() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    model.requestAction([1,1,0,1]); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
    XCTAssertFalse(model.snapOnRelease)
    await transport.hold(operation: "members")
    model.setSnapOnRelease(true); let held = try await transport.waitForHeld(1)
    XCTAssertTrue(model.snapOnRelease); XCTAssertTrue(model.busy)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.sceneRevision, revision)
    try await transport.reply(held[0]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.busy); XCTAssertTrue(model.snapOnRelease)
    XCTAssertEqual(model.selected, [1,-2,2]); XCTAssertEqual(model.paired, [1,-1,1])
    XCTAssertEqual(model.inspection?.point, [1,-2,2]); XCTAssertEqual(model.displayedPair, [1,-1,1])
    XCTAssertEqual(model.actionMatrix, [1,0,0,1]); XCTAssertEqual(model.action?.matrix, [1,0,0,1])
    XCTAssertEqual(model.plane?.normal, [1,-2,0]); XCTAssertEqual(model.sceneRevision, revision + 1)
    let beforeDisable = await transport.totalCount(), identityReceipt = model.action?.id
    model.setSnapOnRelease(false)
    let afterDisable = await transport.totalCount()
    XCTAssertEqual(afterDisable, beforeDisable); XCTAssertFalse(model.snapOnRelease); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.action?.id, identityReceipt)
    XCTAssertEqual(model.selected, [1,-2,2]); XCTAssertEqual(model.paired, [1,-1,1])
  }

  func testFailedAbsorptionRebuildPreservesWholeAcceptedPairScene() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport), translation = [1,1,0,1]
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    model.requestAction(translation); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), points = model.points, revision = model.sceneRevision
    await transport.hold(operation: "members")
    model.absorbAction(translation); let held = try await transport.waitForHeld(1)
    try await transport.fail(held[0]); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, translation)
    XCTAssertEqual(model.points, points); XCTAssertEqual(model.plane?.normal, [1,0,-1])
    XCTAssertEqual(model.sceneRevision, revision)
  }

  func testLateAbsorptionCannotOverwriteARefreshOfTheSignedSelection() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport), translation = [1,1,0,1]
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    model.requestAction(translation); await model.waitForPending()
    await transport.hold(operation: "members")
    model.absorbAction(translation); let held = try await transport.waitForHeld(1)
    model.select([1,0,1]); await model.waitForPending()
    let accepted = try XCTUnwrap(model.action), revision = model.sceneRevision
    XCTAssertNil(model.paired); XCTAssertNil(model.plane); XCTAssertEqual(accepted.matrix, translation)
    try await transport.reply(held[0]); await Task.yield(); await Task.yield()
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertNil(model.paired); XCTAssertNil(model.displayedPair)
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertNil(model.plane)
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, translation)
    XCTAssertEqual(model.sceneRevision, revision); XCTAssertFalse(model.busy); XCTAssertNil(model.error)
  }

  func testSnapRelabelsHiddenSourceSeedAndIdentityKeepsTheRelabelledSelection() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.select([13,20,34]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertFalse(model.selectionShown)
    XCTAssertEqual(model.inspection?.delta, -1368)
    model.requestAction([1,1,0,1]); await model.waitForPending()
    XCTAssertEqual(model.action?.image, [13,-6,27])
    model.snapAction(); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.selected, [13,-6,27])
    XCTAssertEqual(model.inspection?.point, [13,-6,27]); XCTAssertEqual(model.inspection?.delta, -1368)
    XCTAssertFalse(model.selectionShown); XCTAssertEqual(model.actionMatrix, [1,0,0,1])
    XCTAssertEqual(model.action?.point, [13,-6,27]); XCTAssertEqual(model.action?.matrix, [1,0,0,1])
    model.requestAction([1,0,0,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.selected, [13,-6,27])
    XCTAssertEqual(model.inspection?.point, [13,-6,27]); XCTAssertEqual(model.action?.image, [13,-6,27])
    XCTAssertFalse(model.selectionShown)
  }

  func testEitherAbsorbedPairImageOutsideNativeBoundRejectsWithoutPartialRelabelling() async throws {
    let fixture = try PolynomialFixtures()
    let cases = [([1024,-1024,1024],[1,0,1]), ([1,0,1],[-1024,1024,-1024])]
    for (first, second) in cases {
      let transport = PolynomialTransport(fixture), model = model(fixture, transport)
      model.select(first, pair: second); await model.waitForPending()
      model.requestAction([1,1,0,1]); await model.waitForPending()
      XCTAssertNil(model.error)
      let accepted = try XCTUnwrap(model.action), points = model.points, revision = model.sceneRevision
      model.absorbAction([1,1,0,1]); await model.waitForPending()
      XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
      XCTAssertEqual(model.selected, first); XCTAssertEqual(model.paired, second)
      XCTAssertEqual(model.inspection?.point, first); XCTAssertEqual(model.displayedPair, second)
      XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, accepted.matrix)
      XCTAssertEqual(model.points, points); XCTAssertEqual(model.plane?.normal, [1,0,-1])
      XCTAssertEqual(model.sceneRevision, revision)
    }
  }

  func testIntegralImageOfOnePointDoesNotAuthorizeNonIntegralGroupAbsorption() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport), rational = [3,1,1,2]
    model.select([1,0,1], pair: [1,1,1]); await model.waitForPending()
    model.requestAction(rational); await model.waitForPending()
    XCTAssertNil(model.error)
    let accepted = try XCTUnwrap(model.action), points = model.points, revision = model.sceneRevision
    XCTAssertEqual(accepted.image, [1,-2,2]); XCTAssertEqual(accepted.denominator, 5)
    let before = await transport.count(operation: "transform")
    model.absorbAction(rational); await model.waitForPending()
    XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    XCTAssertEqual(model.selected, [1,0,1]); XCTAssertEqual(model.paired, [1,1,1])
    XCTAssertEqual(model.inspection?.point, [1,0,1]); XCTAssertEqual(model.displayedPair, [1,1,1])
    XCTAssertEqual(model.action?.id, accepted.id); XCTAssertEqual(model.actionMatrix, rational)
    XCTAssertEqual(model.points, points); XCTAssertEqual(model.sceneRevision, revision)
    let after = await transport.count(operation: "transform")
    XCTAssertEqual(after, before)
  }

  func testGeneratorAbsorbsExactlyDivisibleNormalizedMatrixAndLeavesNonintegralActionsUnabsorbed() async throws {
    let fixture = try PolynomialFixtures(), transport = PolynomialTransport(fixture)
    let model = model(fixture, transport)
    model.requestAction([2,2,0,2]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.action?.denominator, 4)
    model.applyGenerator([1,-1,0,1]); await model.waitForPending()
    XCTAssertNil(model.error)
    XCTAssertEqual(model.actionMatrix, [1,0,0,1]); XCTAssertEqual(model.action?.matrix, [1,0,0,1])
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.action?.image, [1,-1,2])

    model.requestAction([3,1,1,2]); await model.waitForPending()
    model.applyGenerator([1,1,0,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.action?.denominator, 5)
    XCTAssertEqual(model.actionMatrix, [4,3,1,2]); XCTAssertEqual(model.action?.matrix, [4,3,1,2])
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])

    model.requestAction([1,1,0,9]); await model.waitForPending()
    model.applyGenerator([1,0,0,1]); await model.waitForPending()
    XCTAssertNil(model.error); XCTAssertEqual(model.action?.denominator, 9)
    XCTAssertEqual(model.actionMatrix, [1,1,0,9]); XCTAssertEqual(model.action?.matrix, [1,1,0,9])
    XCTAssertEqual(model.selected, [1,-1,2]); XCTAssertEqual(model.inspection?.point, [1,-1,2])
  }
}
