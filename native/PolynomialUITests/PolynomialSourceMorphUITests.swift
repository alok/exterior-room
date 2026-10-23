// SPDX-License-Identifier: GPL-3.0-or-later
// Actual task-owned simulator UI route. No synthetic model events or gesture retries.
import XCTest

@MainActor final class PolynomialSourceMorphUITests: XCTestCase {
  private enum Failure: Error { case timeout(String) }
  private var deadline = Date.distantFuture
  private let videoName = "lean-starscape-native-source-morph"

  private func wait(_ predicate:NSPredicate,_ element:XCUIElement,_ message:String,timeout:TimeInterval = 10) throws {
    let remaining = deadline.timeIntervalSinceNow
    guard remaining > 0 else { throw Failure.timeout("Source sequence exceeded its 180-second interaction budget") }
    let expectation = XCTNSPredicateExpectation(predicate:predicate,object:element)
    let result = XCTWaiter.wait(for:[expectation],timeout:min(timeout,remaining))
    guard result == .completed else {
      let receipt = XCTAttachment(string:"\(message): \(element.debugDescription)")
      receipt.name = "source-morph-wait-failure"; receipt.lifetime = .keepAlways; add(receipt)
      throw Failure.timeout(message)
    }
  }
  private func live(_ app:XCUIApplication) throws {
    try wait(NSPredicate(format:"label BEGINSWITH %@","Live Lean"),app.staticTexts["poly-status"],"Lean request did not reach accepted state",timeout:15)
    XCTAssertFalse(app.staticTexts["poly-error"].exists)
  }
  private func progress(_ percent:String,_ app:XCUIApplication) throws {
    try wait(NSPredicate(format:"label == %@",percent),app.staticTexts["poly-projection-value"],"Projection progress did not reach \(percent)",timeout:15)
    try wait(NSPredicate(format:"label CONTAINS %@","morph \(percent)"),app.staticTexts["poly-render-stats"],"Renderer did not reach morph \(percent)",timeout:15)
  }
  private func rendered(_ app:XCUIApplication) throws {
    let count = app.staticTexts["poly-count"].label.split(separator:" ").first.map(String.init) ?? ""
    XCTAssertFalse(count.isEmpty)
    try wait(NSPredicate(format:"label CONTAINS %@","\(count) buffered"),app.staticTexts["poly-render-stats"],"Renderer did not accept the displayed catalogue")
  }
  private func label(_ app:XCUIApplication,_ id:String) -> String {
    let element = app.staticTexts[id]
    return element.exists ? element.label : "(absent)"
  }
  private func previewCount(_ app:XCUIApplication) -> Int {
    Int(label(app,"poly-roots-preview-count").split(separator:" ").last ?? "") ?? 0
  }
  private func capture(_ stage:String,_ app:XCUIApplication,extra:[String:String] = [:]) throws {
    guard deadline.timeIntervalSinceNow > 0 else { throw Failure.timeout("Capture after interaction budget") }
    var receipt = extra
    receipt["stage"] = stage
    for id in ["poly-status","poly-count","poly-render-stats","poly-state","poly-plane","poly-members",
      "poly-projection-value","poly-projection-height-value","poly-roots-matrix","poly-roots-gesture",
      "poly-roots-selection","poly-roots-plane","poly-roots-preview-count","poly-roots-preview-catalogue"] {
      receipt[id] = label(app,id)
    }
    let data = try JSONSerialization.data(withJSONObject:receipt,options:[.sortedKeys,.prettyPrinted])
    let attachment = XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
    attachment.name = stage + "-receipt"; attachment.lifetime = .keepAlways; add(attachment)
    print("SOURCE_MORPH_UI_RECEIPT: \(String(decoding:data,as:UTF8.self))")
    try SimulatorCapture.record(stage,in:self)
  }

  func testActualSharedRootsPairAndHeldSourcePreview() throws {
    continueAfterFailure=false; deadline=Date().addingTimeInterval(190)
    let app=XCUIApplication(); app.launchEnvironment["POLYNOMIAL_GESTURE_DIAGNOSTICS"]="1"; app.launch()
    try wait(NSPredicate(format:"exists == true"),app.buttons["poly-connect"],"Launch missing",timeout:15)
    app.buttons["poly-connect"].tap(); try live(app)
    app.buttons["poly-space"].tap(); try wait(NSPredicate(format:"label == %@","Leave"),app.buttons["poly-space"],"Space missing",timeout:15)
    try SimulatorCapture.video("lean-starscape-native-source-input",start:true,in:self)
    defer { try? SimulatorCapture.video("lean-starscape-native-source-input",start:false,in:self) }
    app.buttons["poly-upper"].tap(); try live(app)
    app.buttons["poly-roots-open"].tap()
    let chart=app.descendants(matching:.any)["poly-roots-chart"].firstMatch
    try wait(NSPredicate(format:"exists == true"),chart,"Roots missing")
    app.buttons["poly-pair-next"].tap()
    let value=try XCTUnwrap(chart.value as? String),data=try XCTUnwrap(value.data(using:.utf8))
    let geometry=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
    let pair=try XCTUnwrap(geometry["pair"] as? [Double]); XCTAssertEqual(pair.count,2)
    // Previously measured public visionOS chart route: centered X, upward Y.
    chart.coordinate(withNormalizedOffset:CGVector(dx:pair[0]-0.5,dy:0.5-pair[1])).tap()
    try live(app)
    try wait(NSPredicate(format:"label CONTAINS %@","22 buffered"),app.staticTexts["poly-members"],"Actual shared pair tap not accepted")
    XCTAssertFalse(app.staticTexts["poly-pair-next-state"].exists)
    try capture("source-input-00-actual-shared-roots-pair",app)
    app.buttons["poly-roots-close"].tap(); try wait(NSPredicate(format:"exists == false"),chart,"Roots did not close")
    app.segmentedControls["poly-catalogue"].buttons["Source depth"].tap(); try live(app)
    app.buttons["poly-roots-open"].tap(); try wait(NSPredicate(format:"exists == true"),chart,"Source Roots missing")
    app.buttons["poly-roots-checkpoint"].tap(); try live(app); try rendered(app)
    for _ in 0..<3 { app.buttons["poly-roots-zoom-out"].tap() }
    try capture("source-input-01-d5-complete-root-arc",app)
    app.buttons["poly-roots-fit"].tap()
    app.segmentedControls["poly-roots-mode"].buttons["Move"].tap()
    let before=app.staticTexts["poly-roots-matrix"].label,count=previewCount(app)
    let start=chart.coordinate(withNormalizedOffset:CGVector(dx:-0.2,dy:0))
    let finish=chart.coordinate(withNormalizedOffset:CGVector(dx:0.15,dy:0.05))
    start.press(forDuration:0.25,thenDragTo:finish,withVelocity:.slow,thenHoldForDuration:2)
    let diagnostic=XCTAttachment(string:"Before \(before) · frame \(chart.frame)\n\(label(app,"poly-roots-gesture"))\n\(label(app,"poly-roots-preview-count"))")
    diagnostic.name="held-source-preview-input"; diagnostic.lifetime = .keepAlways; add(diagnostic)
    let after=previewCount(app)
    try capture("source-input-02-held-preview-result",app,extra:["matrixBefore":before,"previewBefore":String(count),"previewAfter":String(after)])
    // A missing input callback is a failed gesture probe, not a model-test substitute.
    XCTAssertGreaterThan(after,count,"No completed Lean crop was observed while the actual drag was held")
    try wait(NSPredicate(format:"label != %@",before),app.staticTexts["poly-roots-matrix"],"Held drag did not commit",timeout:15)
    try live(app); XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, 0, 1) · Δ = -4")
    app.buttons["poly-roots-close"].tap(); try wait(NSPredicate(format:"exists == false"),chart,"Roots did not close")
    app.buttons["poly-projection-up"].tap(); app.buttons["poly-projection-up"].tap()
    try progress("50%",app); try capture("source-input-03-final-half-morph",app)
    app.buttons["poly-projection-up"].tap(); app.buttons["poly-projection-up"].tap()
    try progress("100%",app); try capture("source-input-04-final-full-morph",app)
    app.buttons["poly-origin"].tap()
    try wait(NSPredicate(format:"label CONTAINS %@","target ready"),app.staticTexts["poly-spatial-diagnostic"],"Origin input shell not ready",timeout:10)
    try capture("source-input-05-origin-ready-for-host-probe",app)
    // Leave this task-owned app at Origin for the separately coordinated public Device Hub probe.
  }

  func testSourceMorphLinkedRootsDragAndSharedPairing() throws {
    continueAfterFailure = false
    deadline = Date().addingTimeInterval(180)
    let app = XCUIApplication()
    app.launchEnvironment["POLYNOMIAL_GESTURE_DIAGNOSTICS"] = "1"
    app.launch()
    try wait(NSPredicate(format:"exists == true"),app.buttons["poly-connect"],"Launch controls missing",timeout:15)
    app.buttons["poly-connect"].tap(); try live(app)
    app.buttons["poly-space"].tap()
    try wait(NSPredicate(format:"label == %@","Leave"),app.buttons["poly-space"],"Immersive space did not open",timeout:15)
    try SimulatorCapture.video(videoName,start:true,in:self)
    defer { try? SimulatorCapture.video(videoName,start:false,in:self) }

    app.buttons["poly-upper"].tap(); try live(app)
    app.buttons["poly-pair"].tap(); try live(app)
    XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, 0, 1) · Δ = -4")
    XCTAssertEqual(app.staticTexts["poly-plane"].label,"2a −2c = 0 · -1 and 1")
    app.segmentedControls["poly-catalogue"].buttons["Source depth"].tap(); try live(app)
    XCTAssertTrue(app.staticTexts["poly-count"].label.hasSuffix("signed triples · depth 16"))
    try progress("0%",app); try rendered(app)
    try capture("source-morph-00-p0-unit-pair",app)

    app.buttons["poly-projection-up"].tap(); app.buttons["poly-projection-up"].tap()
    try progress("50%",app); try rendered(app)
    try capture("source-morph-01-p50-unit-pair",app)
    app.buttons["poly-projection-up"].tap(); app.buttons["poly-projection-up"].tap()
    try progress("100%",app)
    // Scrubbing is immediate. Exercise both timed button directions independently.
    XCTAssertEqual(app.buttons["poly-projection"].label,"Lift")
    app.buttons["poly-projection"].tap(); try progress("0%",app)
    XCTAssertEqual(app.buttons["poly-projection"].label,"Project")
    app.buttons["poly-projection"].tap(); try progress("100%",app); try rendered(app)
    try capture("source-morph-02-p100-animated-unit-pair",app)

    app.buttons["poly-roots-open"].tap()
    let chart = app.descendants(matching:.any)["poly-roots-chart"].firstMatch
    try wait(NSPredicate(format:"exists == true"),chart,"Roots window missing")
    app.buttons["poly-roots-checkpoint"].tap(); try live(app); try rendered(app)
    XCTAssertEqual(app.staticTexts["poly-roots-matrix"].label,"M = [3, 1, 1, 2]")
    XCTAssertEqual(app.staticTexts["poly-roots-selection"].label,"x² + 1 · (1, 0, 1) · Δ = -4")
    XCTAssertTrue(app.staticTexts["poly-roots-plane"].label.contains("shown ≈ -2.000 and 1.333"))
    try capture("source-morph-03-d5-p100-linked-roots",app)

    // One real element swipe. Release acceptance and interim preview acceptance are separate evidence.
    app.segmentedControls["poly-roots-mode"].buttons["Move"].tap()
    let matrixBefore = app.staticTexts["poly-roots-matrix"].label
    let previewsBefore = previewCount(app)
    chart.swipeRight(velocity:.slow)
    let gesture = XCTAttachment(string:"Frame \(chart.frame) · layout \(chart.value ?? "none")\nBefore \(matrixBefore)\n\(label(app,"poly-roots-gesture"))\n\(label(app,"poly-roots-preview-count"))")
    gesture.name = "source-roots-slow-swipe-diagnostic"; gesture.lifetime = .keepAlways; add(gesture)
    do {
      try wait(NSPredicate(format:"label != %@",matrixBefore),app.staticTexts["poly-roots-matrix"],"Actual Roots swipe did not change the accepted matrix",timeout:15)
    } catch {
      try? capture("source-morph-04-swipe-unconfirmed",app,extra:["matrixBefore":matrixBefore])
      throw error
    }
    try live(app); try rendered(app)
    XCTAssertEqual(app.staticTexts["poly-roots-status"].label,"Lean accepted rational action · Δ preserved")
    XCTAssertEqual(app.staticTexts["poly-roots-selection"].label,"x² + 1 · (1, 0, 1) · Δ = -4")
    XCTAssertTrue(app.staticTexts["poly-roots-plane"].label.hasPrefix("Base 2a −2c = 0"))
    let previewsAfter = previewCount(app)
    XCTAssertGreaterThanOrEqual(previewsAfter,previewsBefore)
    try capture("source-morph-04-actual-roots-swipe",app,extra:[
      "matrixBefore":matrixBefore,"previewAcceptancesBefore":String(previewsBefore),
      "previewAcceptancesAfter":String(previewsAfter),
      "previewDuringSwipe":previewsAfter > previewsBefore ? "observed" : "not observed; accepted release only"])

    app.buttons["poly-pair-next"].tap()
    try wait(NSPredicate(format:"exists == true"),app.staticTexts["poly-roots-pair-next-state"],"Main Pair next did not arm Roots")
    XCTAssertTrue(app.staticTexts["poly-pair-next-state"].exists)
    app.buttons["poly-roots-pair-next"].tap()
    try wait(NSPredicate(format:"exists == false"),app.staticTexts["poly-pair-next-state"],"Roots Cancel did not clear shared pairing")
    app.buttons["poly-roots-pair-next"].tap()
    try wait(NSPredicate(format:"exists == true"),app.staticTexts["poly-pair-next-state"],"Roots Pair next did not arm main controls")
    app.buttons["poly-roots-close"].tap()
    try wait(NSPredicate(format:"exists == false"),chart,"Roots window did not close")
    XCTAssertFalse(app.staticTexts["poly-pair-next-state"].exists,"Closing Roots clears the shared mode")
    try capture("source-morph-05-roots-closed-unoccluded-scene",app)

    app.buttons["poly-pair-next"].tap()
    try wait(NSPredicate(format:"exists == true"),app.staticTexts["poly-pair-next-state"],"Pairing did not arm before Reset")
    app.buttons["poly-reset"].tap(); try live(app); try rendered(app)
    XCTAssertFalse(app.staticTexts["poly-pair-next-state"].exists)
    XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, -1, 2) · Δ = -7")
    XCTAssertEqual(app.staticTexts["poly-count"].label,"480 signed triples · R6")
    XCTAssertFalse(app.staticTexts["poly-plane"].exists)
    try capture("source-morph-06-reset-clears-pairing",app)
    app.buttons["poly-space"].tap()
  }
}
