// SPDX-License-Identifier: GPL-3.0-or-later
// Offscreen comparison of cached alpha assignments and shared unit-box guide lines.
// No UI/headset/visionOS acceptance assertion. No radius or brightness boost.
// Formula provenance: native/Sources/PolynomialSpace.swift (cone/drawPlane/line/fan/material)
// SHA256 2ef58e419e53157a90d2d66cc6cb827091a3d176a71064ecdd89372ea0298101;
// PolynomialAppearance.swift SHA256 209ad4c7d39f99cc0e397d5bbfc50014dbcb1866c91443c0713b135bc09218e1;
// PolynomialSourceMorph.swift SHA256 9740abb77001c4662222de69208263d9fb59158fa32f40b19cd765bb332a4ca8.
// The shader-independent guide formulas below are copied at Identity only.
// Actual Lean pair normal/endpoints and exported RenderPlan mesh/bodies are input.
// Body alpha is already corrected; guide alpha uses the native correction once.
// Compile only after coordination, with cache and binary under /tmp:
// xcrun --sdk macosx swiftc -parse-as-library -swift-version 6 \
//   -module-cache-path /tmp/exteriorroom-optimization-probe-module-cache \
//   -target arm64-apple-macos26.0 optimization-probe.swift -o /tmp/exteriorroom-optimization-probe
// Run: optimization-probe plan-d16.json lean-d16.json OUTPUT_DIRECTORY

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
  private var materialAlpha: Double

  init(mesh: MeshResource, spec: ProbeInput.Batch, noDepthWrites: Bool) throws {
    data = try LowLevelInstanceData(instanceCount: spec.indices.count,
      instanceCapacity: max(1, spec.indices.count * 2))
    entity = ModelEntity(mesh: mesh, materials: [Self.material(spec, noDepthWrites: noDepthWrites)])
    entity.name = "probe-batch-" + spec.key
    materialAlpha = spec.rawAlpha ?? spec.alpha
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
              replaceModel: Bool = false, noDepthWrites: Bool = false, cacheAlpha: Bool = false) throws -> Bool {
    // Product cache compares snapshot.materialAlpha, the raw Double. The fixture's
    // alpha remains the already-converted value passed to the RealityKit material.
    let rawAlpha = spec.rawAlpha ?? spec.alpha
    let assigned = !cacheAlpha || materialAlpha != rawAlpha
    if assigned {
      let material = Self.material(spec, noDepthWrites: noDepthWrites)
      if replaceModel { entity.model = ModelComponent(mesh: mesh, materials: [material]) }
      else { entity.model?.materials = [material] }
      materialAlpha = rawAlpha
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
    return assigned
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
  private var sharedLineMesh = false
  private lazy var lineMesh = MeshResource.generateBox(size: [1,1,1])
  private(set) var materialConstructors = 0, materialSetters = 0
  private(set) var lineMeshGenerations = 0, lineEntities = 0
  private var unitMeshWasUsed = false
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
             noDepthWrites: Bool = false, cacheAlpha: Bool = false) throws {
    if fresh {
      materialConstructors = 0; materialSetters = 0
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
        materialConstructors += 1
        batches[spec.key] = batch
        cloud.addChild(batch!.entity)
      }
      if try batch!.update(mesh: mesh, state: state, spec: spec, replaceModel: replaceModel,
        noDepthWrites: noDepthWrites, cacheAlpha: cacheAlpha) { materialSetters += 1 }
    }
  }


  func configureGuides(_ definition: GuideDefinition, screen: Bool, plane: Bool, cone: Bool,
                       depthMode: GuideDepthMode, sharedLines: Bool = false) throws {
    for parent in [coneGuides, screenGuides, planeGuides] { parent.children.removeAll() }
    guideMaterialStates = []; guideDepthMode = depthMode; sharedLineMesh = sharedLines
    lineMeshGenerations = 0; lineEntities = 0
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
    let mesh: MeshResource
    if sharedLineMesh {
      mesh = lineMesh
      if !unitMeshWasUsed { lineMeshGenerations += 1; unitMeshWasUsed = true }
    } else { mesh = .generateBox(size: [0.002,length,0.002]); lineMeshGenerations += 1 }
    let entity = ModelEntity(mesh: mesh, materials: [guideMaterial(rgb,alpha:alpha,fan:false,name:name)])
    if sharedLineMesh { entity.scale = [0.002,length,0.002] }
    entity.position = (a+b)/2; entity.orientation = simd_quatf(from:[0,1,0],to:delta/length)
    lineEntities += 1
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



@main private struct OptimizationProbe {
  @MainActor static func main() async {
    do {
      guard CommandLine.arguments.count == 4 else {
        throw ProbeError.invalid("Usage: optimization-probe PLAN_JSON LEAN_JSON OUTPUT_DIRECTORY")
      }
      let planURL = URL(fileURLWithPath:CommandLine.arguments[1]), leanURL = URL(fileURLWithPath:CommandLine.arguments[2])
      let outputURL = URL(fileURLWithPath:CommandLine.arguments[3],isDirectory:true)
      let raw = try Data(contentsOf:planURL), lean = try Data(contentsOf:leanURL)
      let input = try JSONDecoder().decode(ProbeInput.self,from:raw)
      try validate(input)
      guard input.states.flatMap(\.batches).allSatisfy({$0.rawAlpha != nil && $0.rawAlpha!.isFinite}) else {
        throw ProbeError.invalid("Actual product cache comparison requires rawAlpha")
      }
      let guide = try GuideDefinition(plan:raw,lean:lean)
      guard let p0 = input.states.first(where:{$0.name == "p0"}),
        let p50 = input.states.first(where:{$0.name == "p50"}),
        let p1 = input.states.first(where:{$0.name == "p1"}) else { throw ProbeError.invalid("Missing morph states") }
      try FileManager.default.createDirectory(at:outputURL,withIntermediateDirectories:true)
      let scene = try ProbeScene(input:input)
      var captures:[String:[UInt8]] = [:], captureInfo:[[String:Any]] = []
      let runs:[(String,ProbeInput.State,Bool,Bool,Bool)] = [
        ("original-p0",p0,true,false,false), ("original-p50",p50,false,false,false), ("original-p1",p1,false,false,false),
        ("cached-p0",p0,true,true,false), ("cached-p50",p50,false,true,false), ("cached-p1",p1,false,true,false),
        ("shared-line-box-p1",p1,true,false,true)
      ]
      var previousConstructors = 0, previousSetters = 0
      for (name,state,fresh,cacheAlpha,sharedLines) in runs {
        if fresh { previousConstructors = 0; previousSetters = 0 }
        try scene.apply(state,fresh:fresh,cacheAlpha:cacheAlpha)
        // Guides are numerically unchanged during this fixed-Identity morph. Build
        // once per fresh comparison group, as production sourcePlaneKey does.
        if fresh { try scene.configureGuides(guide,screen:true,plane:true,cone:true,depthMode:.fansNoWrites,sharedLines:sharedLines) }
        let pixels = try await scene.capture(); captures[name] = pixels
        try writePNG(pixels,to:outputURL.appendingPathComponent(name+".png"))
        var info = pixelStats(pixels)
        info["name"] = name; info["inputState"] = state.name
        info["cachedAlphaAssignments"] = cacheAlpha; info["sharedUnitBoxLines"] = sharedLines
        info["materialConstructorsCumulative"] = scene.materialConstructors
        info["materialSettersCumulative"] = scene.materialSetters
        info["materialConstructorsThisStep"] = scene.materialConstructors - previousConstructors
        info["materialSettersThisStep"] = scene.materialSetters - previousSetters
        previousConstructors = scene.materialConstructors; previousSetters = scene.materialSetters
        info["guideLineMeshGenerationsInGroup"] = scene.lineMeshGenerations
        info["guideLineEntitiesInGroup"] = scene.lineEntities
        info["bodyMaterialReadback"] = scene.materialReceipt(for:state)
        info["guideMaterials"] = scene.guideMaterialStates
        captureInfo.append(info)
        print("CAPTURE \(name): \(info["nonblackPixels"]!) nonblack pixels; constructors \(scene.materialConstructors), setters \(scene.materialSetters)")
      }
      let receipt:[String:Any] = [
        "schema":"native-optimization-probe-result/v1",
        "scope":"macOS offscreen optimization equivalence diagnostic; not visionOS UI/headset acceptance",
        "nativeSpaceSourceSHA256":"2ef58e419e53157a90d2d66cc6cb827091a3d176a71064ecdd89372ea0298101",
        "inputSHA256":SHA256.hash(data:raw).map{String(format:"%02x",$0)}.joined(),
        "leanInputSHA256":SHA256.hash(data:lean).map{String(format:"%02x",$0)}.joined(),
        "width":ProbeScene.width,"height":ProbeScene.height,"framesPerState":ProbeScene.framesPerState,
        "pixelFormat":"bgra8Unorm_srgb","rootPosition":[0,1.4,-3.1],"rootPitchRadians":0.2814,
        "rootYawRadians":-0.4806,"cameraPosition":[0,1.6,0],"cameraLookDirection":[0,0,-1],
        "verticalFOVDegrees":60,"toneMapping":false,"background":"opaque black",
        "allGuidesPresent":true,"guideFanWritesDepth":false,"guideFanReadsDepth":true,
        "guideLineDepth":"UnlitMaterial defaults unchanged","bodyAlpha":"preconverted fixture values, no second correction",
        "cachePredicate":"previous rawAlpha Double != next rawAlpha Double, initialized at construction",
        "sharedLineTransform":"MeshResource.generateBox([1,1,1]); scale=[0.002,length,0.002]; unchanged rotation and midpoint",
        "captures":captureInfo,
        "originalVersusCachedP0":difference(captures["original-p0"]!,captures["cached-p0"]!),
        "originalVersusCachedP50":difference(captures["original-p50"]!,captures["cached-p50"]!),
        "originalVersusCachedP1":difference(captures["original-p1"]!,captures["cached-p1"]!),
        "originalVersusSharedLineBoxP1":difference(captures["original-p1"]!,captures["shared-line-box-p1"]!)
      ]
      try JSONSerialization.data(withJSONObject:receipt,options:[.prettyPrinted,.sortedKeys])
        .write(to:outputURL.appendingPathComponent("receipt.json"))
      print("Completed seven serial optimization captures; receipt.json written.")
    } catch {
      FileHandle.standardError.write(Data("optimization-probe: \(error)\n".utf8)); exit(1)
    }
  }
}
