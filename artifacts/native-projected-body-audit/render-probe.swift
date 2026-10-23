// SPDX-License-Identifier: GPL-3.0-or-later
// Bounded, offscreen RealityKit material/instance diagnostic. This is not a
// visionOS UI, headset, or cross-renderer visual-parity acceptance test.
//
// Prepare with the local macOS SDK (only after coordination):
//   xcrun --sdk macosx swiftc -parse-as-library -swift-version 6 \
//     -module-cache-path /tmp/exteriorroom-render-probe-module-cache \
//     -target arm64-apple-macos26.0 render-probe.swift -o /tmp/exteriorroom-render-probe
// Run: render-probe render-plan.json OUTPUT_DIRECTORY
// No window, application activation, network request, tracking or simulator use.
// Input alpha is already the actual RealityKit linear-light opacity; do not
// apply PolynomialAppearance.linearLightOpacity a second time.

import Foundation
import AppKit
import RealityKit
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import simd

private struct ProbeInput: Decodable {
  let schema: String
  let mesh: Mesh
  let states: [State]
  struct Mesh: Decodable { let positions: [[Float]]; let indices: [UInt32] }
  struct Glyph: Decodable { let position: [Float]; let factor: Float }
  struct Batch: Decodable {
    let key: String
    let indices: [Int]
    let rgb: [Double]
    let alpha: Double
    let rawAlpha: Double?
  }
  struct State: Decodable { let name: String; let glyphs: [Glyph]; let batches: [Batch] }
}

private enum ProbeError: Error, CustomStringConvertible {
  case invalid(String)
  var description: String { switch self { case .invalid(let text): return text } }
}

// RealityRenderer completion can arrive off the main actor. Exactly one timeout,
// throwing submission, or GPU completion resumes the waiting continuation.
private final class CompletionGate: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, any Error>?
  init(_ continuation: CheckedContinuation<Void, any Error>) { self.continuation = continuation }
  func finish(_ result: Result<Void, any Error>) {
    lock.lock(); let pending = continuation; continuation = nil; lock.unlock()
    pending?.resume(with: result)
  }
}

@MainActor private final class ProbeBatch {
  let entity: ModelEntity
  let data: LowLevelInstanceData

  init(mesh: MeshResource, spec: ProbeInput.Batch, noDepthWrites: Bool) throws {
    data = try LowLevelInstanceData(instanceCount: spec.indices.count,
      instanceCapacity: max(1, spec.indices.count * 2))
    entity = ModelEntity(mesh: mesh, materials: [Self.material(spec, noDepthWrites: noDepthWrites)])
    entity.name = "probe-batch-" + spec.key
  }

  static func material(_ spec: ProbeInput.Batch, noDepthWrites: Bool = false) -> UnlitMaterial {
    var result = UnlitMaterial(applyPostProcessToneMap: false)
    // NSColor is the macOS equivalent of native PolynomialRenderer's UIColor.
    result.color = .init(tint: NSColor(srgbRed: spec.rgb[0], green: spec.rgb[1],
      blue: spec.rgb[2], alpha: 1))
    if spec.alpha < 1 {
      result.blending = .transparent(opacity: .init(floatLiteral: Float(spec.alpha)))
    }
    if noDepthWrites { result.writesDepth = false; result.readsDepth = true }
    return result
  }

  static func materialState(_ material: UnlitMaterial) -> [String: Any] {
    let kind: String, alpha: Float
    switch material.blending {
    case .opaque: kind = "opaque"; alpha = 1
    case .transparent(let opacity): kind = "transparent"; alpha = opacity.scale
    @unknown default: kind = "unknown"; alpha = .nan
    }
    return ["blending": kind, "alpha": alpha.isFinite ? Double(alpha) : -1,
      "writesDepth": material.writesDepth, "readsDepth": material.readsDepth,
      "opacityThreshold": material.opacityThreshold.map { Double($0) as Any } ?? NSNull(),
      "faceCulling": String(describing: material.faceCulling)]
  }

  func update(mesh: MeshResource, state: ProbeInput.State, spec: ProbeInput.Batch,
              replaceModel: Bool = false, noDepthWrites: Bool = false) throws {
    let material = Self.material(spec, noDepthWrites: noDepthWrites)
    if replaceModel {
      // Diagnostic variant: replace the entire component instead of _modify.
      entity.model = ModelComponent(mesh: mesh, materials: [material])
    } else {
      // Exact production material-update expression.
      entity.model?.materials = [material]
    }
    data.instanceCount = spec.indices.count
    var minimum = SIMD3<Float>(repeating: .infinity)
    var maximum = SIMD3<Float>(repeating: -.infinity)
    data.withMutableTransforms { buffer in
      for (slot, index) in spec.indices.enumerated() {
        let glyph = state.glyphs[index]
        let position = SIMD3(glyph.position[0], glyph.position[1], glyph.position[2])
        buffer[slot] = Transform(scale: SIMD3(repeating: glyph.factor), translation: position).matrix
        let radius = SIMD3<Float>(repeating: 0.0075 * glyph.factor)
        minimum = simd_min(minimum, position - radius)
        maximum = simd_max(maximum, position + radius)
      }
    }
    // Exact production order: material assignment, buffer mutation, then a new
    // MeshInstancesComponent containing the same data and recalculated bounds.
    entity.components.set(try MeshInstancesComponent(mesh: mesh, instances: data,
      bounds: BoundingBox(min: minimum, max: maximum)))
  }
}

@MainActor private final class ProbeScene {
  let renderer: RealityRenderer
  let root = Entity()
  let camera = PerspectiveCamera()
  let mesh: MeshResource
  let texture: any MTLTexture
  let output: RealityRenderer.CameraOutput
  private var batches: [String: ProbeBatch] = [:]
  static let width = 1280, height = 960, framesPerState = 4

  init(input: ProbeInput) throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw ProbeError.invalid("No Metal device") }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb,
      width: Self.width, height: Self.height, mipmapped: false)
    descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
    descriptor.storageMode = .shared
    guard let target = device.makeTexture(descriptor: descriptor) else { throw ProbeError.invalid("Texture allocation failed") }
    texture = target
    output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: target))
    var geometry = MeshDescriptor(name: "Actual PolynomialRenderPlan.sphere export")
    geometry.positions = MeshBuffers.Positions(input.mesh.positions.map { SIMD3($0[0], $0[1], $0[2]) })
    geometry.primitives = .triangles(input.mesh.indices)
    mesh = try MeshResource.generate(from: [geometry])
    renderer = try RealityRenderer()
    renderer.cameraSettings.isToneMappingEnabled = false
    renderer.cameraSettings.colorBackground = .color(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    renderer.extendedDynamicRangeOutput = false
    root.position = [0, 1.4, -3.1]
    root.orientation = simd_quatf(angle: 0.2814, axis: [1, 0, 0])
      * simd_quatf(angle: -0.4806, axis: [0, 1, 0])
    camera.position = [0, 1.6, 0]
    camera.camera = PerspectiveCameraComponent(near: 0.01, far: 100,
      fieldOfViewInDegrees: 60, fieldOfViewOrientation: .vertical)
    renderer.entities.append(contentsOf: [root, camera])
    renderer.activeCamera = camera
  }

  func apply(_ state: ProbeInput.State, fresh: Bool = false, replaceModel: Bool = false,
             noDepthWrites: Bool = false) throws {
    if fresh {
      for batch in batches.values { batch.entity.removeFromParent() }
      batches.removeAll()
    }
    let wanted = Set(state.batches.map(\.key))
    for key in Array(batches.keys) where !wanted.contains(key) {
      batches.removeValue(forKey: key)?.entity.removeFromParent()
    }
    // Fixture order is stable so the fresh/reused paths do not deliberately
    // introduce different entity insertion order or transparency sorting.
    for spec in state.batches {
      var batch = batches[spec.key]
      if batch == nil || batch!.data.instanceCapacity < spec.indices.count {
        batch?.entity.removeFromParent()
        batch = try ProbeBatch(mesh: mesh, spec: spec, noDepthWrites: noDepthWrites)
        batches[spec.key] = batch
        root.addChild(batch!.entity)
      }
      try batch!.update(mesh: mesh, state: state, spec: spec, replaceModel: replaceModel,
        noDepthWrites: noDepthWrites)
    }
  }

  func capture() async throws -> [UInt8] {
    for _ in 0..<Self.framesPerState {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        let gate = CompletionGate(continuation)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 20) {
          gate.finish(.failure(ProbeError.invalid("RealityRenderer completion timed out after 20 seconds")))
        }
        do {
          try renderer.updateAndRender(deltaTime: 1.0 / 60.0, cameraOutput: output,
            onComplete: { _ in gate.finish(.success(())) })
        } catch { gate.finish(.failure(error)) }
      }
    }
    var pixels = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
    pixels.withUnsafeMutableBytes { bytes in
      texture.getBytes(bytes.baseAddress!, bytesPerRow: Self.width * 4,
        from: MTLRegionMake2D(0, 0, Self.width, Self.height), mipmapLevel: 0)
    }
    return pixels
  }

  func materialReceipt(for state: ProbeInput.State) -> [String: Any] {
    var missing = 0, maximumError = 0.0, sample: [[String: Any]] = []
    for spec in state.batches {
      guard let material = batches[spec.key]?.entity.model?.materials.first as? UnlitMaterial else {
        missing += 1; continue
      }
      var actual = ProbeBatch.materialState(material)
      let alpha = actual["alpha"] as! Double
      maximumError = max(maximumError, abs(alpha - Double(Float(spec.alpha))))
      if sample.count < 8 {
        actual["key"] = spec.key; actual["intendedAlpha"] = spec.alpha; sample.append(actual)
      }
    }
    return ["checkedBatches": state.batches.count, "missingUnlitMaterial": missing,
      "maxAlphaDifferenceFromIntendedFloat": maximumError, "firstEightMaterials": sample]
  }
}

private func validate(_ input: ProbeInput) throws {
  guard input.schema == "native-render-probe/v1", !input.mesh.positions.isEmpty,
    input.mesh.positions.count <= 10_000, input.mesh.indices.count % 3 == 0,
    input.mesh.positions.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
    input.mesh.indices.allSatisfy({ Int($0) < input.mesh.positions.count }) else {
    throw ProbeError.invalid("Invalid schema or mesh")
  }
  for state in input.states {
    guard !state.glyphs.isEmpty, state.glyphs.count <= 50_000,
      !state.batches.isEmpty, state.batches.count <= 2_048,
      Set(state.batches.map(\.key)).count == state.batches.count,
      state.glyphs.allSatisfy({ $0.position.count == 3 && $0.position.allSatisfy(\.isFinite)
        && $0.factor.isFinite && $0.factor > 0 }),
      state.batches.allSatisfy({ !$0.indices.isEmpty && $0.rgb.count == 3
        && $0.rgb.allSatisfy({ $0.isFinite && (0...1).contains($0) })
        && $0.alpha.isFinite && (0...1).contains($0.alpha)
        && $0.indices.allSatisfy({ state.glyphs.indices.contains($0) }) }) else {
      throw ProbeError.invalid("Invalid or excessive state: \(state.name)")
    }
  }
}

@MainActor private func writePNG(_ bgra: [UInt8], to path: URL) throws {
  var rgba = bgra
  for i in stride(from: 0, to: rgba.count, by: 4) { rgba.swapAt(i, i + 2) }
  let provider = CGDataProvider(data: Data(rgba) as CFData)!
  guard let image = CGImage(width: ProbeScene.width, height: ProbeScene.height,
    bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: ProbeScene.width * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
    let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw ProbeError.invalid("PNG creation failed")
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { throw ProbeError.invalid("PNG encoding failed") }
}

private func pixelStats(_ pixels: [UInt8]) -> [String: Any] {
  var nonblack = 0, above4 = 0, above16 = 0, peak = 0, total = 0
  for i in stride(from: 0, to: pixels.count, by: 4) {
    let value = Int(max(pixels[i], pixels[i + 1], pixels[i + 2]))
    if value > 0 { nonblack += 1 }; if value > 4 { above4 += 1 }; if value > 16 { above16 += 1 }
    peak = max(peak, value); total += value
  }
  return ["nonblackPixels": nonblack, "pixelsMaxRGBAbove4": above4,
    "pixelsMaxRGBAbove16": above16, "peakRGB": peak,
    "meanMaxRGB": Double(total) / Double(pixels.count / 4),
    "bgraSHA256": SHA256.hash(data: Data(pixels)).map { String(format: "%02x", $0) }.joined()]
}

private func difference(_ a: [UInt8], _ b: [UInt8]) -> [String: Any] {
  var changed = 0, maximum = 0, squared = 0.0
  for i in stride(from: 0, to: a.count, by: 4) {
    var differs = false
    for channel in 0..<3 {
      let delta = abs(Int(a[i + channel]) - Int(b[i + channel]))
      differs = differs || delta != 0; maximum = max(maximum, delta); squared += Double(delta * delta)
    }
    if differs { changed += 1 }
  }
  return ["changedRGBPixels": changed, "maxChannelDifference": maximum,
    "rmsChannelDifference": sqrt(squared / Double(a.count / 4 * 3))]
}

@main private struct RenderProbe {
  @MainActor static func main() async {
    do {
      guard CommandLine.arguments.count == 3 else {
        throw ProbeError.invalid("Usage: render-probe INPUT_JSON OUTPUT_DIRECTORY")
      }
      let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
      let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
      let raw = try Data(contentsOf: inputURL)
      let input = try JSONDecoder().decode(ProbeInput.self, from: raw)
      try validate(input)
      guard let p0 = input.states.first(where: { $0.name == "p0" }),
        let p50 = input.states.first(where: { $0.name == "p50" }),
        let p1 = input.states.first(where: { $0.name == "p1" }) else {
        throw ProbeError.invalid("Input needs p0, p50 and p1 states")
      }
      try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
      let scene = try ProbeScene(input: input)
      let positiveP1 = ProbeInput.State(name: "p1-omit-zero-material-alpha", glyphs: p1.glyphs,
        batches: p1.batches.filter { $0.alpha > 0 })
      var captures: [String: [UInt8]] = [:], captureInfo: [[String: Any]] = []
      let runs: [(String, ProbeInput.State, Bool, Bool, Bool)] = [
        ("cold-p0", p0, false, false, false), ("updated-p50", p50, false, false, false),
        ("updated-p1", p1, false, false, false), ("updated-p1-recreate-model", p1, false, true, false),
        ("fresh-p1", p1, true, false, false),
        ("no-depth-writes-cold-p0", p0, true, false, true),
        ("no-depth-writes-updated-p1", p1, false, false, true),
        ("no-depth-writes-fresh-p1", p1, true, false, true),
        ("fresh-p1-omit-zero-alpha", positiveP1, true, false, false)
      ]
      for (name, state, fresh, replaceModel, noDepthWrites) in runs {
        try scene.apply(state, fresh: fresh, replaceModel: replaceModel, noDepthWrites: noDepthWrites)
        let pixels = try await scene.capture()
        captures[name] = pixels
        try writePNG(pixels, to: outputURL.appendingPathComponent(name + ".png"))
        var info = pixelStats(pixels)
        info["name"] = name; info["inputState"] = state.name
        info["instances"] = state.batches.reduce(0) { $0 + $1.indices.count }
        info["batches"] = state.batches.count
        info["depthMode"] = noDepthWrites ? "writesDepth=false,readsDepth=true" : "UnlitMaterial defaults"
        info["modelComponentMaterialReadback"] = scene.materialReceipt(for: state)
        info["instancesWithPositiveMaterialAlpha"] = state.batches.filter { $0.alpha > 0 }.reduce(0) { $0 + $1.indices.count }
        captureInfo.append(info)
        print("CAPTURE \(name): \(info["nonblackPixels"]!) nonblack pixels")
      }
      let defaultMaterial = ProbeBatch.material(p1.batches[0])
      let freshMaterial = UnlitMaterial(applyPostProcessToneMap: false)
      var transparentMaterial = freshMaterial
      transparentMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.5))
      let receipt: [String: Any] = [
        "schema": "native-render-probe-result/v1",
        "inputSHA256": SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined(),
        "platform": ProcessInfo.processInfo.operatingSystemVersionString,
        "scope": "macOS RealityRenderer body-only offscreen diagnostic; not visionOS UI/headset acceptance",
        "width": ProbeScene.width, "height": ProbeScene.height,
        "framesPerState": ProbeScene.framesPerState, "pixelFormat": "bgra8Unorm_srgb",
        "rootPosition": [0, 1.4, -3.1], "rootPitchRadians": 0.2814, "rootYawRadians": -0.4806,
        "cameraPosition": [0, 1.6, 0], "cameraLookDirection": [0, 0, -1], "verticalFOVDegrees": 60,
        "toneMapping": false, "background": "opaque black", "guidesAndSelection": false,
        "alphaInput": "already corrected actual RealityKit opacity; no second correction",
        "defaultMaterialWritesDepth": defaultMaterial.writesDepth,
        "defaultMaterialReadsDepth": defaultMaterial.readsDepth,
        "defaultMaterialFaceCulling": String(describing: defaultMaterial.faceCulling),
        "freshUnlitMaterial": ProbeBatch.materialState(freshMaterial),
        "freshUnlitMaterialAfterTransparentHalf": ProbeBatch.materialState(transparentMaterial),
        "captures": captureInfo,
        "updatedVersusFreshP1": difference(captures["updated-p1"]!, captures["fresh-p1"]!),
        "updatedVersusRecreatedModelP1": difference(captures["updated-p1"]!, captures["updated-p1-recreate-model"]!),
        "defaultVersusNoDepthWritesFreshP1": difference(captures["fresh-p1"]!, captures["no-depth-writes-fresh-p1"]!),
        "noDepthWritesUpdatedVersusFreshP1": difference(captures["no-depth-writes-updated-p1"]!, captures["no-depth-writes-fresh-p1"]!),
        "defaultVersusOmittingZeroAlphaP1": difference(captures["fresh-p1"]!, captures["fresh-p1-omit-zero-alpha"]!)
      ]
      let receiptData = try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
      try receiptData.write(to: outputURL.appendingPathComponent("receipt.json"))
      print("Completed nine serial offscreen captures; receipt.json written.")
    } catch {
      FileHandle.standardError.write(Data("render-probe: \(error)\n".utf8))
      exit(1)
    }
  }
}
