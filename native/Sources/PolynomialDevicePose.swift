// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted by Alok Singh with OpenAI Codex, 2026-10-23, from FareyVision
// Farey/Sources/DevicePoseQuery.swift at 65d50122cfefac86e7626308eaa189dbf5878a7c.
// Original SHA-256: 064f0c6973e9e5589c192a8cadc6c2c220576c8786793e9805ba52502b55d696.
// Changes: testable owned-session lifecycle, bounded startup, cancellation guards,
// and full tracking-state validation. This is renderer placement, not a Lean result.
import Foundation
import simd
#if os(visionOS)
import ARKit
import QuartzCore
#endif

struct PolynomialDevicePoseSample: Sendable {
  let pose: simd_float4x4
  let isTracked: Bool
  let trackingIsTracked: Bool
}

/// The query owns this session. stop() must be safe during partial startup and on
/// a second call if an uncancellable start completes after the first stop.
/// This interface contains no authorization-request or persistent-anchor operation.
@MainActor protocol PolynomialDevicePoseSession: AnyObject {
  var isSupported: Bool { get }
  var requiresAuthorization: Bool { get }
  var isRunning: Bool { get }
  func start() async throws
  func sample() -> PolynomialDevicePoseSample?
  func stop()
}

enum PolynomialDevicePoseQuery {
  enum Failure: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupported, authorizationRequired, sessionFailed(String), notTracked, unusablePose, cancelled
    var description: String {
      switch self {
      case .unsupported: return "world tracking is not supported here"
      case .authorizationRequired: return "world tracking would need authorization here, so it is not started"
      case .sessionFailed(let reason): return "world tracking did not start (\(reason))"
      case .notTracked: return "no fully tracked device pose before the query timed out"
      case .unusablePose: return "the device pose was not a finite rigid transform"
      case .cancelled: return "cancelled"
      }
    }
  }

  /// Captures one device pose, then stops its own tracking session. The pose is the
  /// device's, not a measured head center. No permission request is made.
  @MainActor static func once(timeout: Duration = .seconds(3)) async -> Result<simd_float4x4, Failure> {
    guard !Task.isCancelled else { return .failure(.cancelled) }
    #if os(visionOS)
    return await once(using: ARKitDevicePoseSession(), timeout: timeout)
    #else
    return .failure(.unsupported)
    #endif
  }

  /// Internal dependency seam. Tests supply fake sessions; they never start ARKit.
  @MainActor static func once(using session: any PolynomialDevicePoseSession,
    timeout: Duration = .seconds(3), pollInterval: Duration = .milliseconds(50)
  ) async -> Result<simd_float4x4, Failure> {
    guard !Task.isCancelled else { return .failure(.cancelled) }
    guard session.isSupported else { return .failure(.unsupported) }
    guard !session.requiresAuthorization else { return .failure(.authorizationRequired) }
    defer { session.stop() } // Includes partial startup, startup throw, cancellation and timeout.
    guard timeout > .zero else { return .failure(.notTracked) }
    let operation = Operation(session: session, timeout: timeout,
      pollInterval: max(pollInterval, .milliseconds(1)))
    return await operation.run()
  }

  /// Finite affine transform with orthonormal rotation and determinant +1.
  nonisolated static func isRigid(_ matrix: simd_float4x4, tolerance: Float = 1e-3) -> Bool {
    guard tolerance.isFinite, tolerance > 0 else { return false }
    let columns = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
    guard columns.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite }),
      abs(matrix.columns.0.w) < tolerance, abs(matrix.columns.1.w) < tolerance,
      abs(matrix.columns.2.w) < tolerance, abs(matrix.columns.3.w - 1) < tolerance else { return false }
    let rotation = simd_float3x3(
      SIMD3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
      SIMD3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
      SIMD3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z))
    let gram = rotation.transpose * rotation, identity = matrix_identity_float3x3
    let deviation = [gram.columns.0 - identity.columns.0, gram.columns.1 - identity.columns.1,
      gram.columns.2 - identity.columns.2]
    return deviation.allSatisfy { simd_length($0) < tolerance } && abs(rotation.determinant - 1) < tolerance
  }

  /// A race with explicit ownership rather than a task group: a startup provider
  /// that ignores task cancellation must not hold the caller past its deadline.
  /// stop() runs in once's defer; a late startup completion receives a compensating
  /// stop and cannot sample or win.
  @MainActor private final class Operation {
    let session: any PolynomialDevicePoseSession
    let timeout: Duration
    let pollInterval: Duration
    let expiresAt: ContinuousClock.Instant
    private let cancellation = CancellationFlag()
    private var continuation: CheckedContinuation<Result<simd_float4x4, Failure>, Never>?
    private var worker: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    init(session: any PolynomialDevicePoseSession, timeout: Duration, pollInterval: Duration) {
      self.session = session; self.timeout = timeout; self.pollInterval = pollInterval
      expiresAt = ContinuousClock.now + timeout
    }

    func run() async -> Result<simd_float4x4, Failure> {
      let cancellation = self.cancellation
      return await withTaskCancellationHandler {
        await withCheckedContinuation { reply in
          guard !Task.isCancelled else { reply.resume(returning: .failure(.cancelled)); return }
          continuation = reply
          deadline = Task { @MainActor in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard !Task.isCancelled else { return }
            finish(.failure(.notTracked))
          }
          worker = Task { @MainActor in
            var startupFinished = false
            do {
              guard !Task.isCancelled, continuation != nil else { return }
              guard !cancellation.isCancelled else { finish(.failure(.cancelled)); return }
              guard ContinuousClock.now < expiresAt else { finish(.failure(.notTracked)); return }
              try await session.start()
              startupFinished = true
              guard continuation != nil else { session.stop(); return }
              while continuation != nil {
                try Task.checkCancellation()
                guard !cancellation.isCancelled else { finish(.failure(.cancelled)); return }
                guard ContinuousClock.now < expiresAt else { finish(.failure(.notTracked)); return }
                if session.isRunning, let sample = session.sample(), sample.isTracked, sample.trackingIsTracked {
                  try Task.checkCancellation()
                  guard !cancellation.isCancelled else { finish(.failure(.cancelled)); return }
                  finish(PolynomialDevicePoseQuery.isRigid(sample.pose)
                    ? .success(sample.pose) : .failure(.unusablePose))
                  return
                }
                try await Task.sleep(for: pollInterval)
              }
            } catch {
              if !startupFinished, continuation == nil { session.stop(); return }
              finish(.failure(cancellation.isCancelled || Task.isCancelled || error is CancellationError
                ? .cancelled : .sessionFailed(error.localizedDescription)))
            }
          }
        }
      } onCancel: {
        cancellation.cancel()
        Task { @MainActor in self.finish(.failure(.cancelled)) }
      }
    }

    private func finish(_ result: Result<simd_float4x4, Failure>) {
      guard let reply = continuation else { return }
      continuation = nil
      worker?.cancel(); deadline?.cancel()
      worker = nil; deadline = nil
      reply.resume(returning: result)
    }
  }

  /// Set synchronously by the cancellation handler; consulting it does not wait
  /// for the MainActor cleanup task to be scheduled.
  private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
  }
}

#if os(visionOS)
@MainActor private final class ARKitDevicePoseSession: PolynomialDevicePoseSession {
  private let session = ARKitSession()
  private let provider = WorldTrackingProvider()
  var isSupported: Bool { WorldTrackingProvider.isSupported }
  var requiresAuthorization: Bool { !WorldTrackingProvider.requiredAuthorizations.isEmpty }
  var isRunning: Bool { provider.state == .running }
  func start() async throws { try await session.run([provider]) }
  func sample() -> PolynomialDevicePoseSample? {
    guard !Task.isCancelled, provider.state == .running,
      let anchor = provider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { return nil }
    return PolynomialDevicePoseSample(pose: anchor.originFromAnchorTransform,
      isTracked: anchor.isTracked, trackingIsTracked: anchor.trackingState == .tracked)
  }
  func stop() { session.stop() }
}
#endif
