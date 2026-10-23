import XCTest
@testable import ExteriorRoomCore

private func fixtureData() throws -> Data {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: root.appendingPathComponent("Resources/presets.json"))
}

private actor Gate {
  private var calls: [Int: URLRequest] = [:]
  private var suspended: [Int: CheckedContinuation<(Data, URLResponse), any Error>] = [:]
  func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let object = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    let id = object["id"] as! Int
    calls[id] = request
    return try await withCheckedThrowingContinuation { suspended[id] = $0 }
  }
  func waitFor(_ count: Int) async throws {
    for _ in 0..<1000 {
      if calls.count >= count { return }
      try await Task.sleep(for: .milliseconds(1))
    }
    throw URLError(.timedOut)
  }
  func reply(_ id: Int, data: Data, ok: Bool = true, mismatch: Bool = false) throws {
    let request = calls[id]!
    let input = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    var output = (try JSONSerialization.jsonObject(with: data) as! [[String: Any]])[0]
    // Protocol test stub only: no claim that coefficients correspond to edited inputs.
    output["id"] = mismatch ? id + 100 : id
    output["ok"] = ok
    for axis in ["a", "b", "c"] { output[axis] = input[axis] }
    let bytes = try JSONSerialization.data(withJSONObject: output)
    suspended.removeValue(forKey: id)!.resume(returning: (bytes, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!))
  }
  func fail(_ id: Int) { suspended.removeValue(forKey: id)!.resume(throwing: URLError(.notConnectedToInternet)) }
}

@MainActor final class LeanModelTests: XCTestCase {
  func testGeneratedPresetsMatchBrowserAndLeanValues() throws {
    let model = LeanModel(presetData: try fixtureData())
    XCTAssertEqual(model.presets.count, 3)
    XCTAssertEqual(model.vectors, [[7,1,1],[-2,6,1],[1,1,7]])
    XCTAssertEqual(model.presets.map(\.volume), [294,64,0])
    model.showPreset(1)
    XCTAssertEqual(model.vectors, [[4,0,0],[0,4,0],[0,0,4]])
    XCTAssertEqual(model.result?.wedge, [16,0,0])
    XCTAssertFalse(model.live)
    XCTAssertFalse(model.liveRequested)
    XCTAssertEqual(model.resultOrigin, .bundledExport)
    XCTAssertTrue(model.status.contains("export"))
    model.inside = true; model.showVolume = false; model.selectedVector = 2
    model.reset()
    XCTAssertFalse(model.inside); XCTAssertTrue(model.showVolume); XCTAssertEqual(model.selectedVector, 0)
  }
  func testQuarterSnapMatchesBrowserAndCannotOverflow() {
    XCTAssertEqual(LeanModel.snappedQuarter(-0.125), 0)
    XCTAssertEqual(LeanModel.snappedQuarter(-0.375), -1)
    XCTAssertEqual(LeanModel.snappedQuarter(0.125), 1)
    XCTAssertEqual(LeanModel.snappedQuarter(.greatestFiniteMagnitude), 12)
    XCTAssertEqual(LeanModel.snappedQuarter(-.greatestFiniteMagnitude), -12)
    XCTAssertNil(LeanModel.snappedQuarter(.nan))
    XCTAssertNil(LeanModel.snappedQuarter(.infinity))
  }
  func testExactFractionPresentation() {
    XCTAssertEqual(LeanResult.fraction(294, 64), "147/32")
    XCTAssertEqual(LeanResult.fraction(44, 16), "11/4")
    XCTAssertEqual(LeanResult.fraction(-5, 16), "-5/16")
    XCTAssertEqual(LeanResult.fraction(0, 64), "0")
    XCTAssertEqual(LeanResult.fraction(-64, 64), "-1")
  }
  func testRapidEditsAccumulateAndLateResponseCannotOverwrite() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.setCoordinate(0, quarter: 8)
    try await gate.waitFor(1)
    model.setCoordinate(1, quarter: 2)
    try await gate.waitFor(2)
    XCTAssertEqual(model.vectors[0], [8,2,1])
    try await gate.reply(2, data: data)
    await model.waitForPending()
    try await gate.reply(1, data: data)
    await Task.yield()
    XCTAssertEqual(model.result?.a, [8,2,1])
    XCTAssertTrue(model.live)
  }
  func testFailurePreservesPreviousExactResult() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.setCoordinate(0, quarter: 9)
    try await gate.waitFor(1)
    await gate.fail(1); await model.waitForPending()
    XCTAssertEqual(model.result?.a, [7,1,1])
    XCTAssertEqual(model.vectors[0], [9,1,1])
    XCTAssertFalse(model.live); XCTAssertFalse(model.busy)
    XCTAssertNotNil(model.error); XCTAssertTrue(model.status.contains("Previous"))
  }
  func testInvalidURLInvalidatesAlreadyPendingResponse() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.connect(); try await gate.waitFor(1)
    model.server = "not a URL"; model.connect()
    try await gate.reply(1, data: data); await model.waitForPending()
    XCTAssertFalse(model.live); XCTAssertFalse(model.busy)
    XCTAssertTrue(model.status.contains("invalid bridge"))
  }
  func testRejectsFalseOKAndWrongSequence() async throws {
    for mismatch in [false, true] {
      let data = try fixtureData(), gate = Gate()
      let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
      model.connect(); try await gate.waitFor(1)
      try await gate.reply(1, data: data, ok: mismatch, mismatch: mismatch)
      await model.waitForPending()
      XCTAssertFalse(model.live); XCTAssertNotNil(model.error)
    }
  }
  func testPresetDuringPendingRequestKeepsLiveIntentAndRejectsOldReply() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.connect(); try await gate.waitFor(1)
    XCTAssertTrue(model.liveRequested); XCTAssertTrue(model.busy); XCTAssertFalse(model.live)
    model.showPreset(1); try await gate.waitFor(2)
    XCTAssertTrue(model.busy); XCTAssertTrue(model.liveRequested)
    XCTAssertEqual(model.resultOrigin, .bundledExport)
    XCTAssertEqual(model.result?.volume, 64)
    try await gate.reply(3, data: data); await model.waitForPending()
    try await gate.reply(1, data: data); await Task.yield()
    XCTAssertTrue(model.live)
    XCTAssertEqual(model.result?.a, [4,0,0])
    XCTAssertEqual(model.resultOrigin, .macBridge)
  }
  func testPresetAfterFailureRetriesBecauseLiveIntentPersists() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.connect(); try await gate.waitFor(1)
    await gate.fail(1); await model.waitForPending()
    XCTAssertTrue(model.liveRequested); XCTAssertFalse(model.live)
    model.showPreset(2); try await gate.waitFor(2)
    XCTAssertTrue(model.busy)
    XCTAssertEqual(model.resultOrigin, .bundledExport)
    try await gate.reply(3, data: data); await model.waitForPending()
    XCTAssertTrue(model.live); XCTAssertEqual(model.result?.c, [4,4,0])
  }
  func testFailureAndPreviewNeverRelabelAcceptedMacResponseAsExport() async throws {
    let data = try fixtureData(), gate = Gate()
    let model = LeanModel(presetData: data, transport: { try await gate.send($0) })
    model.connect(); try await gate.waitFor(1)
    try await gate.reply(1, data: data); await model.waitForPending()
    model.previewVector = 0
    XCTAssertEqual(model.displayStatus, "Drag preview · accepted result unchanged")
    XCTAssertEqual(model.result?.a, [7,1,1])
    XCTAssertTrue(model.interactionHint.contains("Preview only"))
    model.previewVector = nil
    model.setCoordinate(0, quarter: 9); try await gate.waitFor(2)
    XCTAssertEqual(model.resultOrigin, .macBridge)
    XCTAssertTrue(model.resultProvenance.contains("response from Mac"))
    await gate.fail(2); await model.waitForPending()
    XCTAssertEqual(model.resultOrigin, .macBridge)
    XCTAssertTrue(model.resultProvenance.contains("response from Mac"))
    XCTAssertEqual(model.result?.a, [7,1,1])
    XCTAssertTrue(model.interactionHint.contains("Previous result"))
  }
  func testOffCenterDragPreservesGrabOffsetAndSnapsOnlyProposedEndpoint() {
    let offset = SIMD3<Float>(repeating: -0.65)
    let endpoint = SIMD3<Float>(1.75, 0.25, 0.25)
    let tip = endpoint + offset
    let grab = tip + SIMD3<Float>(0.02, -0.03, 0.01)
    let drag = EndpointDrag(index: 0, initialTip: tip, initialGrab: grab, inputRevision: 5)
    XCTAssertEqual(drag.endpoint(at: grab, displayOffset: offset), endpoint)
    XCTAssertEqual(drag.endpoint(at: grab + SIMD3<Float>(0.24, 0.01, -0.26), displayOffset: offset),
      SIMD3<Float>(2, 0.25, 0))
    XCTAssertEqual(drag.endpoint(at: grab + SIMD3<Float>(100, -100, 0), displayOffset: offset),
      SIMD3<Float>(3, -3, 0.25))
    XCTAssertNil(drag.endpoint(at: SIMD3<Float>(.nan, 0, 0), displayOffset: offset))
    XCTAssertEqual(drag.initialTip, tip)
  }
}
