import XCTest

@MainActor final class ExteriorRoomUITests: XCTestCase {
  func capture(_ name: String) {
    do { try SimulatorCapture.record(name, in: self) }
    catch { XCTFail("Capture failed: \(error)") }
  }
  func testSpatialControlsAndExactLeanRoundTrip() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["preset-0"].waitForExistence(timeout: 20))
    XCTAssertEqual(app.staticTexts["volume-value"].label, "147/32")
    XCTAssertEqual(app.staticTexts["result-provenance"].label, "Result source: bundled Lean export")
    capture("01-skew-controls")
    app.buttons["connect"].tap()
    let live = app.staticTexts["lean-status"]
    expectation(for: NSPredicate(format: "label == %@", "Live Lean · Mac bridge"), evaluatedWith: live)
    waitForExpectations(timeout: 15)
    XCTAssertEqual(app.staticTexts["result-provenance"].label, "Result source: Lean response from Mac")
    app.buttons["toggle-space"].tap()
    expectation(for: NSPredicate(format: "label == %@", "Leave space"), evaluatedWith: app.buttons["toggle-space"])
    waitForExpectations(timeout: 15)
    capture("02-skew-overview")
    app.buttons["preset-1"].tap()
    expectation(for: NSPredicate(format: "label == %@", "1"), evaluatedWith: app.staticTexts["volume-value"])
    waitForExpectations(timeout: 10)
    expectation(for: NSPredicate(format: "label == %@", "Live Lean · Mac bridge"), evaluatedWith: app.staticTexts["lean-status"])
    waitForExpectations(timeout: 10)
    XCTAssertEqual(app.staticTexts["result-provenance"].label, "Result source: Lean response from Mac")
    capture("03-unit-overview")
    app.buttons["swap"].tap()
    expectation(for: NSPredicate(format: "label == %@", "-1"), evaluatedWith: app.staticTexts["volume-value"])
    waitForExpectations(timeout: 10)
    capture("04-swapped")
    app.buttons["flatten"].tap()
    expectation(for: NSPredicate(format: "label == %@", "0"), evaluatedWith: app.staticTexts["volume-value"])
    waitForExpectations(timeout: 10)
    capture("05-flattened")
    app.buttons["preset-2"].tap(); capture("06-plane")
    app.buttons["preset-0"].tap()
    app.buttons["vector-2"].tap()
    app.buttons["x-plus"].tap()
    XCTAssertEqual(app.staticTexts["coordinate-x"].label, "0.50")
    app.buttons["inside"].tap(); capture("07-inside")
    app.descendants(matching: .any)["volume-toggle"].firstMatch.tap(); capture("08-volume-hidden")
    app.buttons["reset"].tap()
    XCTAssertEqual(app.staticTexts["volume-value"].label, "147/32")
    app.buttons["toggle-space"].tap()
    expectation(for: NSPredicate(format: "label == %@", "Enter space"), evaluatedWith: app.buttons["toggle-space"])
    waitForExpectations(timeout: 15)
    XCTAssertTrue(app.buttons["preset-0"].exists)
    capture("09-returned")
  }

  func testTargetedEndpointDragRoundTrip() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["EXTERIOR_GESTURE_PROBE"] == "1",
      "Opt-in screen-projected simulator drag probe; this does not test tracked-hand input.")
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.buttons["connect"].waitForExistence(timeout: 20))
    app.buttons["connect"].tap()
    expectation(for: NSPredicate(format: "label == %@", "Live Lean · Mac bridge"),
      evaluatedWith: app.staticTexts["lean-status"])
    waitForExpectations(timeout: 15)
    app.buttons["toggle-space"].tap()
    defer {
      if app.buttons["toggle-space"].exists && app.buttons["toggle-space"].label == "Leave space" {
        app.buttons["toggle-space"].tap()
      }
    }
    capture("drag-before")
    let endpoint = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Vector a endpoint")).firstMatch
    guard endpoint.waitForExistence(timeout: 15) else {
      XCTFail("RealityKit endpoint is not accessible to the public XCUI driver; no gesture was sent.")
      return
    }
    let before = ["x", "y", "z"].map { app.staticTexts["coordinate-\($0)"].label }
    let start = endpoint.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = start.withOffset(CGVector(dx: 100, dy: 0))
    let route = XCTAttachment(string: "Public XCUI screen-projected drag from \(start.screenPoint) to \(end.screenPoint); initial coordinates \(before)")
    route.name = "drag-route"; route.lifetime = .keepAlways; add(route)
    start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    expectation(for: NSPredicate(format: "label != %@", before[0]),
      evaluatedWith: app.staticTexts["coordinate-x"])
    waitForExpectations(timeout: 15)
    expectation(for: NSPredicate(format: "label == %@", "Live Lean · Mac bridge"),
      evaluatedWith: app.staticTexts["lean-status"])
    waitForExpectations(timeout: 15)
    XCTAssertEqual(app.staticTexts["result-provenance"].label, "Result source: Lean response from Mac")
    capture("drag-after")
  }
}
