// SPDX-License-Identifier: GPL-3.0-or-later
// Operator sequence follows FareyVision DeviceHubPairProbeUITests.swift (read-only reference).
// State preparation uses ordinary controls. Only external Device Hub sphere clicks can pass the pick assertions.
import XCTest

@MainActor final class PolynomialSpatialPairUITests:XCTestCase {
  private let ownedSimulator="1D261881-0A0F-4DE0-B704-12644E606348"
  private let videoName="lean-starscape-native-spatial-pair"
  private enum Failure:Error { case timedOut(String) }
  private struct Tap:Decodable {
    let callback:Int,revision:Int,entity:String,rootLocal:[Double],resolved:[Int]?,disposition:String
  }
  private struct State:Decodable {
    let selected:[Int]?,pair:[Int]?,normal:[Int]?,equation:String?,members:Int
    let revision:Int,readyRevision:Int,chunks:Int,callbacks:Int
    let spatialCallbacks:Int,spatialReleases:Int,poseEpoch:Int?,poseReady:Bool,action:[Int],spatialStatus:String
    let busy:Bool,pairNext:Bool,ready:Bool,error:String?,tap:Tap?
  }
  private func state(_ app:XCUIApplication) throws -> State {
    let value=try XCTUnwrap(app.staticTexts["poly-spatial-pick-state"].value as? String)
    return try JSONDecoder().decode(State.self,from:Data(value.utf8))
  }
  private func wait(_ predicate:NSPredicate,_ element:XCUIElement,_ message:String,timeout:TimeInterval=20) throws {
    let expectation=XCTNSPredicateExpectation(predicate:predicate,object:element)
    guard XCTWaiter.wait(for:[expectation],timeout:timeout) == .completed else {
      throw Failure.timedOut(message)
    }
  }
  private func live(_ app:XCUIApplication) throws {
    try wait(NSPredicate(format:"label BEGINSWITH %@","Live Lean"),app.staticTexts["poly-status"],"Lean acceptance missing")
    XCTAssertFalse(app.staticTexts["poly-error"].exists)
  }
  private func ready(_ app:XCUIApplication) throws {
    try wait(NSPredicate(format:"value CONTAINS %@","\"ready\":true"),app.staticTexts["poly-spatial-pick-state"],"Current signed collision catalogue not ready")
  }
  private func record(_ stage:String,_ app:XCUIApplication,readyPhase:Int?=nil,origin:Bool=false) throws {
    var receipt:[String:Any] = ["stage":stage,"timestamp":Date().timeIntervalSince1970,
      "simulator":ownedSimulator,"route":origin ? "external public Device Hub Select sky drag":"external public Device Hub Select sphere click",
      "operatorWaitSeconds":120,"modelInjection":false]
    for id in ["poly-state","poly-plane","poly-members","poly-status","poly-error","poly-pair-next-state","poly-render-stats","poly-device-pose","poly-spatial-diagnostic"] {
      let element=app.staticTexts[id]; receipt[id]=element.exists ? element.label : "(absent)"
    }
    for id in ["poly-spatial-pick-state","poly-spatial-pick-trace"] {
      let element=app.staticTexts[id]
      if element.exists,let value=element.value as? String,
        let json=try? JSONSerialization.jsonObject(with:Data(value.utf8)) { receipt[id]=json }
    }
    if let readyPhase {
      receipt["readyPhase"]=readyPhase
      receipt["target"]=origin ? "visible cone-interior sky" as Any:[3,0,3]
    }
    let data=try JSONSerialization.data(withJSONObject:receipt,options:[.sortedKeys])
    let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
    attachment.name=stage+"-receipt";attachment.lifetime = .keepAlways;add(attachment)
    try SimulatorCapture.record(stage,in:self)
    print("\(origin ? "SPATIAL_ORIGIN":"SPATIAL_PAIR")_UI_RECEIPT: \(String(decoding:data,as:UTF8.self))")
    if let readyPhase {
      print("\(origin ? "SPATIAL_ORIGIN":"SPATIAL_PAIR")_READY phase=\(readyPhase) simulator=\(ownedSimulator) timestamp=\(Date().timeIntervalSince1970) target=\(origin ? "cone-interior sky":"(3,0,3)") wait=120s")
    }
  }
  private func select(_ point:String,_ app:XCUIApplication) throws {
    let field=app.textFields["poly-entry"]
    field.tap()
    let previous=field.value as? String ?? ""
    field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:previous.count)+point)
    app.buttons["poly-select"].tap();try live(app);try ready(app)
  }

  func testActualDeviceHubSpherePairing() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["POLYNOMIAL_SPATIAL_PAIR_PROBE"] == "1",
      "Operator-assisted opt-in: run-ui-tests.py --scheme PolynomialRoom --spatial-pair-probe")
    try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == ownedSimulator,
      "Never launch this probe on another owner's simulator")
    continueAfterFailure=false
    let app=XCUIApplication()
    app.launchEnvironment["POLYNOMIAL_GESTURE_DIAGNOSTICS"]="1"
    app.launch()
    try wait(NSPredicate(format:"exists == true"),app.buttons["poly-connect"],"Launch controls missing")
    app.buttons["poly-connect"].tap();try live(app)
    app.buttons["poly-space"].tap()
    try wait(NSPredicate(format:"label == %@","Leave"),app.buttons["poly-space"],"Immersive space did not open")
    app.buttons["poly-reset"].tap();try live(app);try ready(app)
    XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, -1, 2) · Δ = -7")
    XCTAssertEqual(app.buttons["poly-radius"].label,"R6")
    try SimulatorCapture.video(videoName,start:true,in:self)
    defer { try? SimulatorCapture.video(videoName,start:false,in:self) }
    do {
      app.buttons["poly-pair-next"].tap()
      let before=try state(app)
      XCTAssertTrue(before.pairNext);XCTAssertNil(before.pair)
      try record("spatial-pair-01-ready",app,readyPhase:1)
      try wait(NSPredicate(format:"value CONTAINS %@","\"pair\":[3,0,3]"),app.staticTexts["poly-spatial-pick-state"],"No real sphere pair accepted within 120 seconds",timeout:120)
      try live(app)
      let paired=try state(app),tap=try XCTUnwrap(paired.tap)
      XCTAssertGreaterThan(paired.callbacks,before.callbacks)
      XCTAssertEqual(tap.resolved,[3,0,3]);XCTAssertEqual(tap.revision,before.revision)
      XCTAssertTrue(tap.entity.hasPrefix("polynomial-batch:"));XCTAssertEqual(tap.rootLocal.count,3)
      XCTAssertEqual(paired.selected,[1,-1,2]);XCTAssertEqual(paired.pair,[3,0,3])
      XCTAssertEqual(paired.normal,[1,-2,-1]);XCTAssertEqual(paired.members,18)
      XCTAssertEqual(paired.equation,"2a −2b −2c = 0");XCTAssertFalse(paired.pairNext)
      XCTAssertNil(paired.error);try record("spatial-pair-02-accepted",app)

      try select("3,0,3",app)
      app.buttons["poly-pair-next"].tap()
      let refusalBefore=try state(app)
      XCTAssertEqual(refusalBefore.selected,[3,0,3]);XCTAssertNil(refusalBefore.pair);XCTAssertTrue(refusalBefore.pairNext)
      try record("spatial-pair-03-same-direction-ready",app,readyPhase:2)
      try wait(NSPredicate(format:"label CONTAINS %@","same primitive direction"),app.staticTexts["poly-error"],"No real same-sphere rejection within 120 seconds",timeout:120)
      let refused=try state(app),secondTap=try XCTUnwrap(refused.tap)
      XCTAssertGreaterThan(refused.callbacks,refusalBefore.callbacks)
      XCTAssertEqual(secondTap.resolved,[3,0,3]);XCTAssertEqual(secondTap.revision,refusalBefore.revision)
      XCTAssertEqual(refused.selected,[3,0,3]);XCTAssertNil(refused.pair);XCTAssertNil(refused.normal)
      XCTAssertEqual(refused.revision,refusalBefore.revision);XCTAssertTrue(refused.pairNext)
      XCTAssertFalse(refused.busy);XCTAssertTrue(refused.error?.contains("same primitive direction") == true)
      try record("spatial-pair-04-same-direction-refused",app)
      app.buttons["poly-reset"].tap();try live(app)
      XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, -1, 2) · Δ = -7")
      XCTAssertFalse(app.staticTexts["poly-pair-next-state"].exists)
      app.buttons["poly-space"].tap()
      try wait(NSPredicate(format:"label == %@","Enter space"),app.buttons["poly-space"],"Space did not close cleanly")
    } catch {
      try? record("spatial-pair-failure",app)
      throw error
    }
  }

  func testActualDeviceHubOriginUpperAndLower() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["POLYNOMIAL_SPATIAL_ORIGIN_PROBE"] == "1",
      "Operator-assisted opt-in: run-ui-tests.py --scheme PolynomialRoom --spatial-origin-probe")
    try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == ownedSimulator,
      "Never launch this probe on another owner's simulator")
    continueAfterFailure=false
    let app=XCUIApplication();app.launchEnvironment["POLYNOMIAL_GESTURE_DIAGNOSTICS"]="1";app.launch()
    try wait(NSPredicate(format:"exists == true"),app.buttons["poly-connect"],"Launch controls missing")
    app.buttons["poly-connect"].tap();try live(app)
    app.buttons["poly-space"].tap()
    try wait(NSPredicate(format:"label == %@","Leave"),app.buttons["poly-space"],"Immersive space did not open")
    app.buttons["poly-reset"].tap();try live(app)
    app.buttons["poly-upper"].tap();try live(app)
    app.buttons["poly-pair"].tap();try live(app)
    let accepted=try state(app)
    XCTAssertEqual(accepted.selected,[1,0,1]);XCTAssertEqual(accepted.pair,[1,1,1])
    XCTAssertEqual(accepted.normal,[1,0,-1]);XCTAssertEqual(accepted.members,22)
    app.buttons["poly-origin"].tap()
    let recording="lean-starscape-native-device-pose-origin"
    try SimulatorCapture.video(recording,start:true,in:self)
    defer { try? SimulatorCapture.video(recording,start:false,in:self) }
    do {
      var epoch:Int?
      for phase in 1...2 {
        if phase == 2 { app.buttons["poly-flip-nappe"].tap() }
        try wait(NSPredicate(format:"value CONTAINS %@","\"poseReady\":true"),app.staticTexts["poly-spatial-pick-state"],"Measured device pose was not installed",timeout:15)
        let before=try state(app)
        if let epoch { XCTAssertEqual(before.poseEpoch,epoch,"Flip must retain its frozen device pose epoch") }
        else { epoch=before.poseEpoch;XCTAssertNotNil(epoch) }
        try record("spatial-origin-\(phase)-ready",app,readyPhase:phase,origin:true)
        try wait(NSPredicate(format:"value CONTAINS %@","\"spatialReleases\":\(before.spatialReleases+1)"),app.staticTexts["poly-spatial-pick-state"],"No completed real sky drag within120seconds",timeout:120)
        try live(app)
        let moved=try state(app)
        try record("spatial-origin-\(phase)-observed",app,origin:true)
        XCTAssertGreaterThan(moved.spatialCallbacks,before.spatialCallbacks)
        XCTAssertNotEqual(moved.action,before.action,"A callback or preview alone is not accepted movement")
        XCTAssertGreaterThan(moved.revision,before.revision)
        XCTAssertEqual(moved.selected,accepted.selected);XCTAssertEqual(moved.pair,accepted.pair)
        XCTAssertEqual(moved.normal,accepted.normal);XCTAssertEqual(moved.members,accepted.members)
        XCTAssertTrue(moved.poseReady);XCTAssertEqual(moved.poseEpoch,epoch);XCTAssertNil(moved.error)
      }
      app.buttons["poly-reset"].tap();try live(app)
      XCTAssertEqual(app.staticTexts["poly-state"].label,"(1, -1, 2) · Δ = -7")
      XCTAssertFalse((try state(app)).poseReady)
      app.buttons["poly-space"].tap()
      try wait(NSPredicate(format:"label == %@","Enter space"),app.buttons["poly-space"],"Space did not close cleanly")
      app.buttons["poly-space"].tap()
      try wait(NSPredicate(format:"label == %@","Leave"),app.buttons["poly-space"],"Space did not re-enter")
      try ready(app)
      let reentered=try state(app)
      XCTAssertEqual(reentered.selected,[1,-1,2]);XCTAssertNil(reentered.pair);XCTAssertNil(reentered.normal)
      XCTAssertEqual(reentered.action,[1,0,0,1]);XCTAssertFalse(reentered.poseReady);XCTAssertNil(reentered.poseEpoch)
      XCTAssertEqual(app.staticTexts["poly-placement"].label,"Overview · stationary object")
      try record("spatial-origin-reset-exit-reentry-overview",app,origin:true)
      app.buttons["poly-space"].tap()
      try wait(NSPredicate(format:"label == %@","Enter space"),app.buttons["poly-space"],"Re-entered space did not close cleanly")
    } catch { try? record("spatial-origin-failure",app,origin:true);throw error }
  }
}
