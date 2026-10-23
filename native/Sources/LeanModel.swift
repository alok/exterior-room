// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Observation
import simd

struct LeanResult: Decodable, Sendable {
  let ok: Bool
  let id: Int
  let scale: Int
  let a: [Int]
  let b: [Int]
  let c: [Int]
  let wedge: [Int]
  let swappedWedge: [Int]
  let selfWedge: [Int]
  let volume: Int
  let vertices: [[Int]]
  var vectors: [[Int]] { [a, b, c] }
  var wedgeText: String { "(" + wedge.map { Self.fraction($0, 16) }.joined(separator: ", ") + ")" }
  var volumeText: String { Self.fraction(volume, 64) }
  static func fraction(_ numerator: Int, _ denominator: Int) -> String {
    guard denominator > 0 else { return "?" }
    var a = numerator.magnitude, b = UInt(denominator)
    while b != 0 { let remainder = a % b; a = b; b = remainder }
    let divisor = Int(a), n = numerator / divisor, d = denominator / divisor
    return d == 1 ? String(n) : "\(n)/\(d)"
  }
  var isValid: Bool {
    ok && scale == 4 && vectors.allSatisfy { $0.count == 3 && $0.allSatisfy { (-12...12).contains($0) } }
      && wedge.count == 3 && swappedWedge.count == 3 && selfWedge.count == 3
      && vertices.count == 8 && vertices.allSatisfy { $0.count == 3 && $0.allSatisfy { (-36...36).contains($0) } }
  }
  func point(_ values: [Int]) -> SIMD3<Float> {
    SIMD3<Float>(Float(values[0]), Float(values[1]), Float(values[2])) / Float(scale)
  }
}

private struct LeanRequest: Encodable {
  let id: Int
  let a: [Int]
  let b: [Int]
  let c: [Int]
}

// Renderer-only drag state. This never computes exterior-algebra values.
struct EndpointDrag {
  let index: Int
  let initialTip: SIMD3<Float>
  let initialGrab: SIMD3<Float>
  let inputRevision: Int
  func point(at grab: SIMD3<Float>) -> SIMD3<Float> { initialTip + grab - initialGrab }
  func endpoint(at grab: SIMD3<Float>, displayOffset: SIMD3<Float>) -> SIMD3<Float>? {
    let p = point(at: grab) - displayOffset
    guard let x = LeanModel.snappedQuarter(p.x), let y = LeanModel.snappedQuarter(p.y),
      let z = LeanModel.snappedQuarter(p.z) else { return nil }
    return SIMD3<Float>(Float(x), Float(y), Float(z)) / 4
  }
}

enum ResultOrigin: Equatable {
  case bundledExport, macBridge
  var text: String {
    switch self {
    case .bundledExport: "Result source: bundled Lean export"
    case .macBridge: "Result source: Lean response from Mac"
    }
  }
}

@MainActor @Observable final class LeanModel {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
  static let presetNames = ["Skew", "Unit", "Plane"]
  var result: LeanResult?
  var vectors: [[Int]] = [[0,0,0],[0,0,0],[0,0,0]]
  var presets: [LeanResult] = []
  var presetIndex = 0
  var selectedVector = 0
  var server = "http://127.0.0.1:8787"
  var live = false
  private(set) var liveRequested = false
  private(set) var resultOrigin = ResultOrigin.bundledExport
  var previewVector: Int?
  var busy = false
  var inside = false
  var showVolume = true
  var spaceOpen = false
  var transitioning = false
  var status = "Lean export · preset playback"
  var error: String?
  var displayStatus: String {
    previewVector == nil ? status : "Drag preview · accepted result unchanged"
  }
  var resultProvenance: String { result == nil ? "No accepted Lean result" : resultOrigin.text }
  var interactionHint: String {
    if previewVector != nil { return "Preview only · release to ask Lean" }
    if busy { return "Waiting for Lean · previous result visible" }
    if error != nil { return "Previous result visible · retry the Mac bridge" }
    return live ? "Drag an endpoint · release to compute" : "Presets work offline · edits need the Mac bridge"
  }
  private var requestID = 0
  var inputRevision: Int { requestID }
  private var pending: Task<Void, Never>?
  private let transport: Transport

  init(presetData: Data? = nil, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
    self.transport = transport
    do {
      let data: Data
      if let presetData { data = presetData }
      else if let url = Bundle.main.url(forResource: "presets", withExtension: "json") { data = try Data(contentsOf: url) }
      else { throw CocoaError(.fileNoSuchFile) }
      presets = try JSONDecoder().decode([LeanResult].self, from: data)
      guard presets.count == Self.presetNames.count, presets.allSatisfy(\.isValid) else { throw CocoaError(.coderInvalidValue) }
      result = presets[0]
      vectors = presets[0].vectors
    } catch { self.error = "Lean exports unavailable: \(error.localizedDescription)" }
  }

  func showPreset(_ index: Int) {
    guard presets.indices.contains(index) else { return }
    let reconnect = liveRequested
    pending?.cancel()
    requestID += 1
    busy = false
    live = false
    presetIndex = index
    result = presets[index]
    resultOrigin = .bundledExport
    vectors = presets[index].vectors
    status = "Lean export · preset playback"
    error = nil
    if reconnect { evaluate() }
  }
  func reset() { inside = false; showVolume = true; selectedVector = 0; showPreset(0) }
  func connect() { guard result != nil else { return }; evaluate() }
  func swap() {
    guard result != nil else { return }
    vectors.swapAt(0, 1)
    presetIndex = -1
    evaluate()
  }
  func flatten() {
    guard result != nil else { return }
    vectors[2] = vectors[1]
    selectedVector = 2
    presetIndex = -1
    evaluate()
  }
  func setCoordinate(_ axis: Int, quarter: Int) {
    guard result != nil, (0..<3).contains(axis), (0..<3).contains(selectedVector) else { return }
    vectors[selectedVector][axis] = min(12, max(-12, quarter))
    presetIndex = -1
    evaluate()
  }
  nonisolated static func snappedQuarter(_ value: Float) -> Int? {
    guard value.isFinite else { return nil }
    // Match JavaScript Math.round, including negative half-way values. Clamp before Int conversion.
    return Int(floor(min(12.0, max(-12.0, Double(value) * 4)) + 0.5))
  }
  func moveVector(_ index: Int, to point: SIMD3<Float>) {
    guard result != nil, (0..<3).contains(index),
      let x = Self.snappedQuarter(point.x), let y = Self.snappedQuarter(point.y),
      let z = Self.snappedQuarter(point.z) else { return }
    vectors[index] = [x,y,z]
    selectedVector = index
    presetIndex = -1
    evaluate()
  }
  func waitForPending() async { await pending?.value }

  private func evaluate() {
    liveRequested = true
    pending?.cancel()
    requestID += 1
    let id = requestID
    live = false
    busy = false
    guard let root = URL(string: server), ["http", "https"].contains(root.scheme), root.host != nil else {
      status = "Previous result · invalid bridge URL"
      error = "Enter a local Mac bridge URL."
      return
    }
    let requested = vectors
    busy = true
    status = "Waiting for Lean · previous result visible"
    error = nil
    let body = LeanRequest(id: id, a: requested[0], b: requested[1], c: requested[2])
    pending = Task {
      do {
        var request = URLRequest(url: root.appendingPathComponent("api/evaluate"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let accepted = try JSONDecoder().decode(LeanResult.self, from: data)
        guard accepted.isValid, accepted.id == id, accepted.vectors == requested else { throw URLError(.cannotParseResponse) }
        guard !Task.isCancelled, id == requestID else { return }
        result = accepted
        resultOrigin = .macBridge
        live = true
        status = "Live Lean · Mac bridge"
        busy = false
      } catch {
        guard !Task.isCancelled, id == requestID else { return }
        busy = false
        live = false
        status = "Previous result · bridge unavailable"
        self.error = error.localizedDescription
      }
    }
  }
}
