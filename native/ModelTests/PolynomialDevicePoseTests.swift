// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23.
// Fake-session lifecycle and numerical validation only; no tracking, permissions,
// simulator input, physical-headset behavior or Lean theorem is tested here.
import XCTest
import simd
@testable import ExteriorRoomCore

@MainActor private final class PoseSessionFixture: PolynomialDevicePoseSession {
  enum StartError: LocalizedError {
    case refused
    var errorDescription: String? { "fixture startup failure" }
  }
  var isSupported = true
  var requiresAuthorization = false
  var isRunning = false
  var runningAfterStart = true
  var holdStartup = false
  var failStartup = false
  var samples: [PolynomialDevicePoseSample?] = []
  private(set) var starts = 0
  private(set) var stops = 0
  private(set) var sampleCalls = 0
  private(set) var samplesOutsideRunning = 0
  private(set) var startupReply: CheckedContinuation<Void, any Error>?

  func start() async throws {
    starts += 1
    if holdStartup {
      // Deliberately ignores Task cancellation and stop(). The query must stop
      // again if this late completion makes the provider running after cleanup.
      try await withCheckedThrowingContinuation { startupReply = $0 }
    }
    isRunning = runningAfterStart
    if failStartup { throw StartError.refused }
  }
  func releaseStartup() {
    let reply = startupReply; startupReply = nil; reply?.resume()
  }
  func sample() -> PolynomialDevicePoseSample? {
    sampleCalls += 1
    if !isRunning { samplesOutsideRunning += 1 }
    return samples.isEmpty ? nil : samples.removeFirst()
  }
  func stop() { stops += 1; isRunning = false }
}

@MainActor final class PolynomialDevicePoseTests: XCTestCase {
  private enum FixtureFailure: Error { case waitExpired }

  private func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<1_000 {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(1))
    }
    throw FixtureFailure.waitExpired
  }

  private func tracked(_ pose: simd_float4x4 = matrix_identity_float4x4) -> PolynomialDevicePoseSample {
    PolynomialDevicePoseSample(pose: pose, isTracked: true, trackingIsTracked: true)
  }

  private func assertFailure(_ result: Result<simd_float4x4, PolynomialDevicePoseQuery.Failure>,
    _ expected: PolynomialDevicePoseQuery.Failure, file: StaticString = #filePath, line: UInt = #line
  ) {
    guard case .failure(let actual) = result else {
      XCTFail("Expected failure \(expected), received a pose", file: file, line: line); return
    }
    XCTAssertEqual(actual, expected, file: file, line: line)
  }

  func testRigidRotationAndTranslationAreAcceptedWithoutChangingPose() async throws {
    var pose = simd_float4x4(simd_quatf(angle: 0.7, axis: simd_normalize(SIMD3<Float>(1, 2, 3))))
    pose.columns.3 = SIMD4(1.25, -2.5, 3.75, 1)
    XCTAssertTrue(PolynomialDevicePoseQuery.isRigid(pose))
    let session = PoseSessionFixture(); session.samples = [tracked(pose)]
    let result = await PolynomialDevicePoseQuery.once(using: session)
    let received = try result.get()
    XCTAssertEqual(received.columns.0, pose.columns.0); XCTAssertEqual(received.columns.1, pose.columns.1)
    XCTAssertEqual(received.columns.2, pose.columns.2); XCTAssertEqual(received.columns.3, pose.columns.3)
    XCTAssertEqual(session.starts, 1); XCTAssertEqual(session.sampleCalls, 1)
    XCTAssertEqual(session.stops, 1); XCTAssertFalse(session.isRunning)
  }

  func testRigidValidationRejectsScaleReflectionShearNonfiniteAndProjectiveMatrices() {
    var scale = matrix_identity_float4x4; scale.columns.0.x = 1.01
    var reflection = matrix_identity_float4x4; reflection.columns.0.x = -1
    var shear = matrix_identity_float4x4; shear.columns.1.x = 0.1
    var nan = matrix_identity_float4x4; nan.columns.3.x = .nan
    var infinity = matrix_identity_float4x4; infinity.columns.2.y = .infinity
    var projective = matrix_identity_float4x4; projective.columns.0.w = 0.01
    var homogeneous = matrix_identity_float4x4; homogeneous.columns.3.w = 2
    for pose in [scale, reflection, shear, nan, infinity, projective, homogeneous] {
      XCTAssertFalse(PolynomialDevicePoseQuery.isRigid(pose))
    }
    for tolerance: Float in [0, -1, .nan, .infinity] {
      XCTAssertFalse(PolynomialDevicePoseQuery.isRigid(matrix_identity_float4x4, tolerance: tolerance))
    }
  }

  func testBothTrackingFlagsAreRequiredBeforeReturningAPose() async throws {
    let session = PoseSessionFixture()
    session.samples = [
      PolynomialDevicePoseSample(pose: matrix_identity_float4x4, isTracked: false, trackingIsTracked: true),
      PolynomialDevicePoseSample(pose: matrix_identity_float4x4, isTracked: true, trackingIsTracked: false),
      tracked()
    ]
    let result = await PolynomialDevicePoseQuery.once(using: session, pollInterval: .milliseconds(1))
    _ = try result.get()
    XCTAssertEqual(session.sampleCalls, 3); XCTAssertEqual(session.stops, 1)
    XCTAssertEqual(session.samplesOutsideRunning, 0)
  }

  func testProviderMustBeRunningBeforeItCanBeSampled() async throws {
    let session = PoseSessionFixture(); session.runningAfterStart = false; session.samples = [tracked()]
    let query = Task { await PolynomialDevicePoseQuery.once(using: session, pollInterval: .milliseconds(1)) }
    try await waitUntil { session.starts == 1 }
    try await Task.sleep(for: .milliseconds(5))
    XCTAssertEqual(session.sampleCalls, 0)
    session.isRunning = true
    let result = await query.value
    _ = try result.get()
    XCTAssertEqual(session.sampleCalls, 1); XCTAssertEqual(session.samplesOutsideRunning, 0)
    XCTAssertEqual(session.stops, 1)
  }

  func testFullyTrackedButUnusablePoseFailsAndStops() async {
    let session = PoseSessionFixture()
    var bad = matrix_identity_float4x4; bad.columns.2.z = -1
    session.samples = [tracked(bad)]
    let result = await PolynomialDevicePoseQuery.once(using: session)
    assertFailure(result, .unusablePose)
    XCTAssertEqual(session.starts, 1); XCTAssertEqual(session.sampleCalls, 1)
    XCTAssertEqual(session.stops, 1); XCTAssertFalse(session.isRunning)
  }

  func testPreflightNeverStartsOrSamplesUnsupportedOrAuthorizationRequiringSessions() async {
    for unsupported in [true, false] {
      let session = PoseSessionFixture()
      session.isSupported = !unsupported; session.requiresAuthorization = !unsupported
      session.samples = [tracked()]
      let result = await PolynomialDevicePoseQuery.once(using: session)
      assertFailure(result, unsupported ? .unsupported : .authorizationRequired)
      XCTAssertEqual(session.starts, 0); XCTAssertEqual(session.sampleCalls, 0); XCTAssertEqual(session.stops, 0)
    }
  }

  func testStartupFailureStopsPartiallyStartedSessionWithoutSampling() async {
    let session = PoseSessionFixture(); session.failStartup = true; session.samples = [tracked()]
    let result = await PolynomialDevicePoseQuery.once(using: session)
    assertFailure(result, .sessionFailed("fixture startup failure"))
    XCTAssertEqual(session.starts, 1); XCTAssertEqual(session.sampleCalls, 0)
    XCTAssertEqual(session.stops, 1); XCTAssertFalse(session.isRunning)
  }

  func testAlreadyCancelledQueryDoesNotStartOrSample() async {
    let session = PoseSessionFixture(); session.samples = [tracked()]
    let query = Task { await PolynomialDevicePoseQuery.once(using: session) }
    query.cancel()
    let result = await query.value
    assertFailure(result, .cancelled)
    XCTAssertEqual(session.starts, 0); XCTAssertEqual(session.sampleCalls, 0); XCTAssertEqual(session.stops, 0)
  }

  func testCancellationDuringStartupStopsImmediatelyAndAgainAfterLateStartWithoutSampling() async throws {
    let session = PoseSessionFixture(); session.holdStartup = true; session.samples = [tracked()]
    let query = Task { await PolynomialDevicePoseQuery.once(using: session) }
    try await waitUntil { session.startupReply != nil }
    query.cancel()
    let result = await query.value
    assertFailure(result, .cancelled)
    XCTAssertEqual(session.stops, 1); XCTAssertEqual(session.sampleCalls, 0)
    session.releaseStartup()
    try await waitUntil { session.stops == 2 }
    XCTAssertFalse(session.isRunning); XCTAssertEqual(session.sampleCalls, 0)
  }

  func testCancellationDuringPollingNeverSamplesAgain() async throws {
    let session = PoseSessionFixture()
    let query = Task { await PolynomialDevicePoseQuery.once(using: session, pollInterval: .milliseconds(1)) }
    try await waitUntil { session.sampleCalls > 0 }
    let beforeCancellation = session.sampleCalls
    query.cancel()
    let result = await query.value
    assertFailure(result, .cancelled)
    try await Task.sleep(for: .milliseconds(5))
    XCTAssertEqual(session.sampleCalls, beforeCancellation)
    XCTAssertEqual(session.stops, 1); XCTAssertFalse(session.isRunning)
  }

  func testTimeoutWhilePollingStopsAndReturnsNoPose() async {
    let session = PoseSessionFixture()
    let result = await PolynomialDevicePoseQuery.once(using: session, timeout: .milliseconds(20),
      pollInterval: .milliseconds(1))
    assertFailure(result, .notTracked)
    XCTAssertEqual(session.starts, 1); XCTAssertGreaterThan(session.sampleCalls, 0)
    XCTAssertEqual(session.stops, 1); XCTAssertFalse(session.isRunning)
  }

  func testTimeoutIncludesUncancellableStartupAndStopsItsLateCompletion() async throws {
    let session = PoseSessionFixture(); session.holdStartup = true; session.samples = [tracked()]
    let query = Task { await PolynomialDevicePoseQuery.once(using: session, timeout: .milliseconds(20)) }
    try await waitUntil { session.startupReply != nil }
    let result = await query.value
    assertFailure(result, .notTracked)
    XCTAssertEqual(session.stops, 1); XCTAssertEqual(session.sampleCalls, 0)
    session.releaseStartup()
    try await waitUntil { session.stops == 2 }
    XCTAssertFalse(session.isRunning); XCTAssertEqual(session.sampleCalls, 0)
  }

  func testNonpositiveTimeoutDoesNotStartOrSample() async {
    for timeout: Duration in [.zero, .milliseconds(-1)] {
      let session = PoseSessionFixture(); session.samples = [tracked()]
      let result = await PolynomialDevicePoseQuery.once(using: session, timeout: timeout)
      assertFailure(result, .notTracked)
      XCTAssertEqual(session.starts, 0); XCTAssertEqual(session.sampleCalls, 0); XCTAssertEqual(session.stops, 1)
    }
  }

  #if !os(visionOS)
  func testPlatformEntryPointDoesNotStartTrackingOnMacOS() async {
    let result = await PolynomialDevicePoseQuery.once()
    assertFailure(result, .unsupported)
  }
  #endif
}
