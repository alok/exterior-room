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
    capture("01-skew-controls")
    app.buttons["connect"].tap()
    let live = app.staticTexts["lean-status"]
    expectation(for: NSPredicate(format: "label == %@", "Live Lean · Mac bridge"), evaluatedWith: live)
    waitForExpectations(timeout: 15)
    app.buttons["toggle-space"].tap()
    expectation(for: NSPredicate(format: "label == %@", "Leave space"), evaluatedWith: app.buttons["toggle-space"])
    waitForExpectations(timeout: 15)
    capture("02-skew-overview")
    app.buttons["preset-1"].tap()
    expectation(for: NSPredicate(format: "label == %@", "1"), evaluatedWith: app.staticTexts["volume-value"])
    waitForExpectations(timeout: 10)
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
}
