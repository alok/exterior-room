// SPDX-License-Identifier: GPL-3.0-or-later
// Offscreen guide-occlusion diagnostic derived from the frozen body probe.
// No UI/headset/visionOS acceptance assertion. No radius or brightness boost.
// Formula provenance: native/Sources/PolynomialSpace.swift (cone/drawPlane/line/fan/material)
// SHA256 c7836bd5a8ff7e1902d43d3ec1954732f094adc16cc80256a014da1566ed7051;
// PolynomialAppearance.swift SHA256 209ad4c7d39f99cc0e397d5bbfc50014dbcb1866c91443c0713b135bc09218e1;
// PolynomialSourceMorph.swift SHA256 9740abb77001c4662222de69208263d9fb59158fa32f40b19cd765bb332a4ca8.
// The shader-independent guide formulas below are copied at Identity only.
// Actual Lean pair normal/endpoints and exported RenderPlan mesh/bodies are input.
// Body alpha is already corrected; guide alpha uses the native correction once.
// Compile only after coordination, with cache and binary under /tmp:
// xcrun --sdk macosx swiftc -parse-as-library -swift-version 6 \
//   -module-cache-path /tmp/exteriorroom-guide-probe-module-cache \
//   -target arm64-apple-macos26.0 guide-probe.swift -o /tmp/exteriorroom-guide-probe
// Run: guide-probe plan-d16.json lean-d16.json OUTPUT_DIRECTORY

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


private enum GuideDepthMode: String { case defaults, fansNoWrites, allNoWrites }

private struct GuideDefinition {
  let depth = 16, height = 9.6
  let scale: Float = 0.96 / 16
  let cartesianNormal: SIMD3<Float>
  let endpoints: [Double]
  init(plan: Data, lean: Data) throws {
    let planObject = try JSONSerialization.jsonObject(with: plan) as? [String: Any]
    let leanObject = try JSONSerialization.jsonObject(with: lean) as? [String: Any]
    guard let settings = planObject?["settings"] as? [String: Any],
      settings["depth"] as? Int == 16, settings["matrix"] as? [Int] == [1,0,0,1],
      settings["height"] as? Double == 9.6,
      settings["selected"] as? [Int] == [1,0,1], settings["second"] as? [Int] == [1,1,1],
      let cases = leanObject?["cases"] as? [[String: Any]], cases.count > 1,
      let request = cases[1]["request"] as? [String: Any], request["op"] as? String == "pair",
      request["first"] as? [Int] == [1,0,1], request["second"] as? [Int] == [1,1,1],
      let response = cases[1]["response"] as? [String: Any], response["ok"] as? Bool == true,
      let normal = response["cartesianNormal"] as? [Int], normal == [0,0,-2],
      let ends = response["endpoints"] as? [[String: Any]], ends.count == 2 else {
      throw ProbeError.invalid("Guide fixture must be accepted D16/unit-pair/Identity with height9.6")
    }
    cartesianNormal = SIMD3(Float(normal[0]),Float(normal[1]),Float(normal[2]))
    endpoints = try ends.map { endpoint in
      guard endpoint["kind"] as? String == "rational", let numerator = endpoint["numerator"] as? Int,
        let denominator = endpoint["denominator"] as? Int, denominator != 0 else {
        throw ProbeError.invalid("Expected exact rational unit-pair endpoints")
      }
      return Double(numerator)/Double(denominator)
    }
    guard endpoints == [-1,1] else { throw ProbeError.invalid("Unexpected unit-pair endpoints") }
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
  private let coneGuides = Entity(), cloud = Entity(), screenGuides = Entity(), planeGuides = Entity()
  private(set) var guideMaterialStates: [[String: Any]] = []
  private var guideDepthMode = GuideDepthMode.defaults
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
    // Exact relevant native root-child order: guides, cloud, projection, plane.
    for child in [coneGuides, cloud, screenGuides, planeGuides] { root.addChild(child) }
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
        cloud.addChild(batch!.entity)
      }
      try batch!.update(mesh: mesh, state: state, spec: spec, replaceModel: replaceModel,
        noDepthWrites: noDepthWrites)
    }
  }


  func configureGuides(_ definition: GuideDefinition, screen: Bool, plane: Bool, cone: Bool,
                       depthMode: GuideDepthMode) throws {
    for parent in [coneGuides, screenGuides, planeGuides] { parent.children.removeAll() }
    guideMaterialStates = []; guideDepthMode = depthMode
    let guide = Self.rgb(0x54e9f5), guideLine = Self.rgb(0x7896a8), amber = Self.rgb(0xffba6b)
    if cone {
      for sign: Float in [1, -1] {
        let ring = (0...64).map { i -> SIMD3<Float> in
          let angle = Float(i) * 2 * .pi / 64
          let extent: Float = sign < 0 ? 0.288 : 0.96
          return [extent*cos(angle), extent*sign, extent*sin(angle)]
        }
        try fan([.zero] + ring, rgb: guide, alpha: 0.018, parent: coneGuides, name: "cone-fan")
        for i in 0..<64 {
          line(ring[i], ring[i+1], rgb: guideLine, alpha: 0.26, parent: coneGuides, name: "cone-ring-line")
          if i % 8 == 0 { line(.zero, ring[i], rgb: guideLine, alpha: 0.26, parent: coneGuides, name: "cone-radial-line") }
        }
      }
    }
    if screen {
      let height = Float(definition.height) * definition.scale
      let ring = (0...64).map { i -> SIMD3<Float> in
        let angle = Float(i) * 2 * .pi / 64
        return [height*cos(angle), height, height*sin(angle)]
      }
      try fan([[0,height,0]] + ring, rgb: guide, alpha: 0.1, parent: screenGuides, name: "screen-fan")
      for i in 0..<64 { line(ring[i], ring[i+1], rgb: guide, alpha: 0.8, parent: screenGuides, name: "screen-ring-line") }
    }
    if plane {
      let n = definition.cartesianNormal
      let horizontal = sqrt(n.x*n.x+n.z*n.z), length = simd_length(n)
      guard horizontal > 0, length > 0 else { throw ProbeError.invalid("Degenerate fixture plane") }
      let u = SIMD3<Float>(-n.z/horizontal, 0, n.x/horizontal)
      let v = SIMD3<Float>(-n.x*n.y/(horizontal*length), horizontal/length, -n.z*n.y/(horizontal*length))
      let boundary = (0...64).map { i -> SIMD3<Float> in
        let angle = Float(i) * 2 * .pi / 64, d = u*cos(angle) + v*sin(angle)
        return d * (Float(definition.depth) * definition.scale / max(abs(d.y),sqrt(d.x*d.x+d.z*d.z)))
      }
      let displayedBoundary = boundary.map { q -> SIMD3<Float> in
        // Identity: native mapped(point) leaves each Float unchanged.
        let clipped = Self.clipPlaneVertex(SIMD3(Double(q.x), Double(q.y), Double(q.z)),
          radius: Double(Float(definition.depth)*definition.scale)) ?? .zero
        return SIMD3(Float(clipped.x), Float(clipped.y), Float(clipped.z))
      }
      try fan([.zero] + displayedBoundary, rgb: amber, alpha: 0.045, parent: planeGuides, name: "cutting-plane-fan")
      for i in 0..<64 { line(displayedBoundary[i], displayedBoundary[i+1], rgb: amber, alpha: 0.35, parent: planeGuides, name: "cutting-plane-edge") }
      let directions = definition.endpoints.map { value -> SIMD3<Float> in
        guard value.isFinite else { return [0,1,1] }
        let angle = 2 * atan(value)
        return [Float(sin(angle)), 1, Float(-cos(angle))]
      }
      for q in directions {
        if q.y > 0.000001 { line(-0.288*q/q.y, 0.96*q/q.y, rgb: amber, alpha: 0.7, parent: planeGuides, name: "cutting-plane-endpoint") }
      }
      // Source mode passes showProjection:false to drawPlane: no radial chord.
    }
  }

  private static func rgb(_ hex: Int) -> SIMD3<Double> {
    SIMD3(Double((hex >> 16)&255), Double((hex >> 8)&255), Double(hex&255))/255
  }
  private static func linearLightOpacity(_ alpha: Double, color: SIMD3<Double>) -> Float {
    func linear(_ s: Double) -> Double { s <= 0.04045 ? s/12.92 : pow((s+0.055)/1.055,2.4) }
    let c = max(color.x,color.y,color.z)
    return Float(c > 0 ? linear(alpha*c)/linear(c) : alpha)
  }
  private static func clipPlaneVertex(_ point: SIMD3<Double>, radius: Double) -> SIMD3<Double>? {
    guard radius > 0, radius.isFinite, (0..<3).allSatisfy({point[$0].isFinite}) else { return nil }
    let norm = hypot(hypot(point.x,point.y),point.z)
    let bound = max(1,hypot(point.x,point.z)/radius,point.y/(point.y >= 0 ? radius : -0.3*radius),norm/(1.5*radius))
    return point/bound
  }
  private func guideMaterial(_ rgb: SIMD3<Double>, alpha: Double, fan: Bool, name: String) -> UnlitMaterial {
    var material = UnlitMaterial(applyPostProcessToneMap: false)
    material.color = .init(tint: NSColor(srgbRed: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    if alpha < 1 { material.blending = .transparent(opacity: .init(floatLiteral: Self.linearLightOpacity(alpha,color:rgb))) }
    if fan { material.faceCulling = .none }
    if guideDepthMode == .allNoWrites || (fan && guideDepthMode == .fansNoWrites) {
      material.writesDepth = false; material.readsDepth = true
    }
    var state = ProbeBatch.materialState(material)
    state["name"] = name; state["rawAlpha"] = alpha; state["rgb"] = [rgb.x,rgb.y,rgb.z]
    state["geometry"] = fan ? "triangle fan" : "0.002m box line"
    // Record each distinct material role, with an entity count; preserve exact values.
    if let index = guideMaterialStates.firstIndex(where: { ($0["name"] as? String) == name }) {
      guideMaterialStates[index]["entityCount"] = (guideMaterialStates[index]["entityCount"] as! Int) + 1
    } else { state["entityCount"] = 1; guideMaterialStates.append(state) }
    return material
  }
  private func line(_ a: SIMD3<Float>, _ b: SIMD3<Float>, rgb: SIMD3<Double>, alpha: Double,
                    parent: Entity, name: String) {
    let delta = b-a, length = simd_length(delta)
    guard length > 0.00001 else { return }
    let entity = ModelEntity(mesh: .generateBox(size: [0.002,length,0.002]),
      materials: [guideMaterial(rgb,alpha:alpha,fan:false,name:name)])
    entity.position = (a+b)/2; entity.orientation = simd_quatf(from:[0,1,0],to:delta/length)
    parent.addChild(entity)
  }
  private func fan(_ vertices: [SIMD3<Float>], rgb: SIMD3<Double>, alpha: Double,
                   parent: Entity, name: String) throws {
    var descriptor = MeshDescriptor(name: "Approximate polynomial display surface")
    descriptor.positions = MeshBuffers.Positions(vertices)
    descriptor.primitives = .triangles((1..<(vertices.count-1)).flatMap { [0,UInt32($0),UInt32($0+1)] })
    // Unlike the app's silent try?, diagnostic failure stops and is recorded.
    let mesh = try MeshResource.generate(from:[descriptor])
    parent.addChild(ModelEntity(mesh:mesh,materials:[guideMaterial(rgb,alpha:alpha,fan:true,name:name)]))
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

private func baselineBodyVisibility(_ baseline: [UInt8], _ next: [UInt8]) -> [String: Any] {
  var bright = 0, belowQuarter = 0
  for i in stride(from: 0, to: baseline.count, by: 4) {
    let before = Int(max(baseline[i],baseline[i+1],baseline[i+2]))
    guard before > 16 else { continue }
    bright += 1
    let after = Int(max(next[i],next[i+1],next[i+2]))
    if 4 * after < before { belowQuarter += 1 }
  }
  return ["baselineMaxRGBAbove16Pixels": bright,
    "baselineBrightPixelsNowBelowQuarterBrightness": belowQuarter]
}


@main private struct GuideProbe {
  @MainActor static func main() async {
    do {
      guard CommandLine.arguments.count == 4 else {
        throw ProbeError.invalid("Usage: guide-probe PLAN_JSON LEAN_JSON OUTPUT_DIRECTORY")
      }
      let planURL = URL(fileURLWithPath: CommandLine.arguments[1])
      let leanURL = URL(fileURLWithPath: CommandLine.arguments[2])
      let outputURL = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
      let raw = try Data(contentsOf: planURL), lean = try Data(contentsOf: leanURL)
      let input = try JSONDecoder().decode(ProbeInput.self, from: raw)
      try validate(input)
      let guide = try GuideDefinition(plan:raw,lean:lean)
      guard let p1 = input.states.first(where:{$0.name == "p1"}) else { throw ProbeError.invalid("Missing P1 state") }
      try FileManager.default.createDirectory(at:outputURL,withIntermediateDirectories:true)
      let scene = try ProbeScene(input: input)
      var captures:[String:[UInt8]] = [:], captureInfo:[[String:Any]] = []
      let runs:[(String,Bool,Bool,Bool,GuideDepthMode)] = [
        ("body-only",false,false,false,.defaults),
        ("body-plus-screen",true,false,false,.defaults),
        ("body-plus-plane",false,true,false,.defaults),
        ("body-plus-cone",false,false,true,.defaults),
        ("body-plus-all-guides",true,true,true,.defaults),
        ("body-plus-all-guide-fans-no-depth-write",true,true,true,.fansNoWrites),
        ("body-plus-all-guides-no-depth-write",true,true,true,.allNoWrites)
      ]
      for (name,screen,plane,cone,depthMode) in runs {
        // All bodies fresh, identical order/data/materials. Only guide membership or
        // its declared depth-writing setting varies between these diagnostic cases.
        try scene.apply(p1,fresh:true)
        try scene.configureGuides(guide,screen:screen,plane:plane,cone:cone,depthMode:depthMode)
        let pixels = try await scene.capture(); captures[name] = pixels
        try writePNG(pixels,to:outputURL.appendingPathComponent(name+".png"))
        var info = pixelStats(pixels)
        info["name"] = name; info["guides"] = ["screen":screen,"plane":plane,"cone":cone]
        info["guideDepthMode"] = depthMode.rawValue
        info["guideMaterials"] = scene.guideMaterialStates
        info["bodyMaterialReadback"] = scene.materialReceipt(for:p1)
        info["bodyInstances"] = p1.batches.reduce(0){$0+$1.indices.count}
        info["positiveMaterialBodyInstances"] = p1.batches.filter{$0.alpha>0}.reduce(0){$0+$1.indices.count}
        if let baseline = captures["body-only"] {
          info["differenceFromBodyOnly"] = difference(baseline,pixels)
          info["baselineBodyVisibility"] = baselineBodyVisibility(baseline,pixels)
        }
        captureInfo.append(info)
        print("CAPTURE \(name): \(info["nonblackPixels"]!) nonblack pixels")
      }
      let receipt:[String:Any] = [
        "schema":"native-guide-probe-result/v1",
        "inputSHA256":SHA256.hash(data:raw).map{String(format:"%02x",$0)}.joined(),
        "leanInputSHA256":SHA256.hash(data:lean).map{String(format:"%02x",$0)}.joined(),
        "scope":"macOS offscreen body-plus-guide occlusion diagnostic; not visionOS UI/headset acceptance",
        "platform":ProcessInfo.processInfo.operatingSystemVersionString,
        "nativeFormulaSources":[
          "native/Sources/PolynomialSpace.swift":"c7836bd5a8ff7e1902d43d3ec1954732f094adc16cc80256a014da1566ed7051",
          "native/Sources/PolynomialAppearance.swift":"209ad4c7d39f99cc0e397d5bbfc50014dbcb1866c91443c0713b135bc09218e1",
          "native/Sources/PolynomialSourceMorph.swift":"9740abb77001c4662222de69208263d9fb59158fa32f40b19cd765bb332a4ca8"],
        "width":ProbeScene.width,"height":ProbeScene.height,"framesPerState":ProbeScene.framesPerState,
        "pixelFormat":"bgra8Unorm_srgb","rootPosition":[0,1.4,-3.1],
        "rootPitchRadians":0.2814,"rootYawRadians":-0.4806,"cameraPosition":[0,1.6,0],
        "cameraLookDirection":[0,0,-1],"verticalFOVDegrees":60,"toneMapping":false,
        "background":"opaque black","nativeRelevantChildOrder":["guides","cloud","projection","plane"],
        "depth":16,"sourceHeight":9.6,"sourceHeightMetres":Double(Float(9.6)*guide.scale),
        "pairCartesianNormal":[0,0,-2],"pairEndpointValues":guide.endpoints,
        "bodyInput":"identical P1 exported mesh/transforms/radii and already-corrected material alpha in every capture",
        "guideAlpha":"native linearLightOpacity once; no opacity/radius gain",
        "captures":captureInfo,
        "allGuidesVersusFansNoDepthWrite":difference(captures["body-plus-all-guides"]!,captures["body-plus-all-guide-fans-no-depth-write"]!),
        "allGuidesVersusAllNoDepthWrite":difference(captures["body-plus-all-guides"]!,captures["body-plus-all-guides-no-depth-write"]!)
      ]
      try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys])
        .write(to:outputURL.appendingPathComponent("receipt.json"))
      print("Completed seven serial guide captures; receipt.json written.")
    } catch {
      FileHandle.standardError.write(Data("guide-probe: \(error)\n".utf8)); exit(1)
    }
  }
}
