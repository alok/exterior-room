// SPDX-License-Identifier: GPL-3.0-or-later
// Mesh/material and endpoint patterns adapted from FareyVision 8b32d7a.
// New exterior-algebra scene by Alok Singh with OpenAI Codex, 2026-10-23.
import RealityKit
import SwiftUI

struct ExteriorSpace: View {
  @Environment(LeanModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @State private var scene = ExteriorRenderer()
  @GestureState private var dragActive = false
  @State private var dragInvalidated = false

  var body: some View {
    RealityView { content, attachments in
      content.add(scene.root)
      if let result = model.result { scene.render(result, inside: model.inside, showVolume: model.showVolume) }
      if let panel = attachments.entity(for: "receipt") {
        panel.position = [0.75, 2.1, -2.4]
        panel.scale = [1.8, 1.8, 1.8]
        content.add(panel)
      }
      if let controls = attachments.entity(for: "controls") {
        controls.position = [-0.65, 1.25, -1.55]
        controls.scale = [1.25, 1.25, 1.25]
        content.add(controls)
      }
    } update: { _, attachments in
      if let result = model.result { scene.render(result, inside: model.inside, showVolume: model.showVolume) }
      if let panel = attachments.entity(for: "receipt") {
        panel.position = model.inside ? [0.75, 2.15, -1.8] : [0.75, 2.1, -2.4]
      }
    } attachments: {
      Attachment(id: "controls") {
        ControlView().environment(model).frame(width: 700, height: 730).glassBackgroundEffect()
      }
      Attachment(id: "receipt") {
        VStack(spacing: 6) {
          Text(model.displayStatus).font(.caption.weight(.semibold))
            .foregroundStyle(model.previewVector == nil && model.live ? Color.mint : Color.secondary)
          if let result = model.result {
            Text("a ∧ b = \(result.wedgeText)")
              .font(.system(.headline, design: .monospaced))
            Text("e₁₂ · e₁₃ · e₂₃     |     volume = \(result.volumeText)")
              .font(.system(.caption, design: .monospaced))
          }
          if let error = model.error {
            Text(error).font(.caption2).foregroundStyle(.orange).lineLimit(2)
          }
          Text(model.resultProvenance).font(.caption2).foregroundStyle(.secondary)
          Text(model.interactionHint)
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16).frame(width: 430).glassBackgroundEffect()
      }
    }
    .gesture(
      DragGesture().targetedToAnyEntity()
        .updating($dragActive) { _, active, _ in active = true }
        .onChanged { value in
          guard !dragInvalidated, model.live, !model.busy, value.entity.name.hasPrefix("handle-") else { return }
          let local = value.convert(value.location3D, from: .local, to: scene.geometry)
          let start = value.convert(value.startLocation3D, from: .local, to: scene.geometry)
          model.previewVector = scene.previewDrag(value.entity, at: local, start: start, revision: model.inputRevision)
        }
        .onEnded { value in
          defer {
            scene.finishDrag()
            model.previewVector = nil
            if let result = model.result { scene.render(result, inside: model.inside, showVolume: model.showVolume) }
          }
          guard model.live, !model.busy, let drag = scene.drag, drag.inputRevision == model.inputRevision
          else { return }
          let local = value.convert(value.location3D, from: .local, to: scene.geometry)
          if let endpoint = drag.endpoint(at: local, displayOffset: ExteriorRenderer.displayOffset) {
            model.moveVector(drag.index, to: endpoint)
          }
        }
    )
    .onChange(of: dragActive) { _, active in
      if !active { cancelPreview(); dragInvalidated = false }
    }
    .onChange(of: model.inputRevision) { _, _ in
      if dragActive { dragInvalidated = true }
      cancelPreview()
    }
    .onChange(of: model.inside) { _, _ in
      if dragActive { dragInvalidated = true }
      cancelPreview()
    }
    .onAppear { model.spaceOpen = true }
    .onDisappear {
      scene.finishDrag()
      model.previewVector = nil
      model.spaceOpen = false
      model.transitioning = false
      openWindow(id: "launch")
    }
  }

  private func cancelPreview() {
    scene.finishDrag()
    model.previewVector = nil
    if let result = model.result { scene.render(result, inside: model.inside, showVolume: model.showVolume) }
  }
}

@MainActor final class ExteriorRenderer {
  let root = Entity()
  let geometry = Entity()
  private(set) var drag: EndpointDrag?
  private var preview: Entity?
  private var lastKey = ""
  static let displayOffset = SIMD3<Float>(-0.65, -0.65, -0.65)
  private let colors: [UIColor] = [UIColor(red: 1, green: 145.0/255, blue: 117.0/255, alpha: 1),
    UIColor(red: 103.0/255, green: 228.0/255, blue: 200.0/255, alpha: 1),
    UIColor(red: 184.0/255, green: 160.0/255, blue: 1, alpha: 1)]

  init() { root.addChild(geometry) }

  func previewDrag(_ entity: Entity, at grab: SIMD3<Float>, start: SIMD3<Float>, revision: Int) -> Int? {
    guard let index = Int(entity.name.replacingOccurrences(of: "handle-", with: "")),
      (0..<3).contains(index) else { return nil }
    if drag == nil {
      drag = EndpointDrag(index: index, initialTip: entity.position, initialGrab: start, inputRevision: revision)
      var material = UnlitMaterial(color: colors[index])
      material.blending = .transparent(opacity: .init(floatLiteral: 0.4))
      let ghost = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [material])
      let label = ModelEntity(mesh: .generateText("preview " + ["a", "b", "c"][index],
        extrusionDepth: 0.001, font: .systemFont(ofSize: 0.09)),
        materials: [UnlitMaterial(color: .white)])
      label.position = [0.10, 0.09, 0]
      ghost.addChild(label)
      geometry.addChild(ghost)
      preview = ghost
    }
    guard let drag, drag.index == index else { return nil }
    guard let endpoint = drag.endpoint(at: grab, displayOffset: Self.displayOffset) else { return nil }
    preview?.position = endpoint + Self.displayOffset
    return index
  }

  func finishDrag() {
    preview?.removeFromParent()
    preview = nil
    drag = nil
    lastKey = ""
  }

  func render(_ result: LeanResult, inside: Bool, showVolume: Bool) {
    guard drag == nil else { return }
    root.position = inside ? [0.75, 1.2, -0.8] : [0.75, 1.25, -2.4]
    root.scale = SIMD3<Float>(repeating: inside ? 0.85 : 0.5)
    let key = "\(result.vectors)-\(result.vertices)-\(showVolume)"
    guard key != lastKey else { return }
    lastKey = key
    geometry.children.removeAll()
    let center = -Self.displayOffset
    let p = result.vertices.map { result.point($0) - center }

    // Vertex order supplied by Lean: 0,a,b,c,a+b,a+c,b+c,a+b+c.
    let edges = [[0,1],[0,2],[0,3],[1,4],[1,5],[2,4],[2,6],[3,5],[3,6],[4,7],[5,7],[6,7]]
    for edge in edges where showVolume || edge.allSatisfy({ [0,1,2,4].contains($0) }) {
      addLine(p[edge[0]], p[edge[1]], radius: 0.008, color: UIColor.white.withAlphaComponent(0.5))
    }
    let faces: [[UInt32]] = [[0,1,4,2],[0,1,5,3],[0,2,6,3],[1,4,7,5],[2,4,7,6],[3,5,7,6]]
    for (i, face) in faces.enumerated() where showVolume || i == 0 {
      var descriptor = MeshDescriptor(name: "Accepted Lean parallelepiped face")
      descriptor.positions = MeshBuffers.Positions(p)
      descriptor.primitives = .triangles([face[0],face[1],face[2],face[0],face[2],face[3]])
      if let mesh = try? MeshResource.generate(from: [descriptor]) {
        var material = UnlitMaterial(color: i == 0 ? .systemMint : .systemCyan)
        material.blending = .transparent(opacity: .init(floatLiteral: i == 0 ? 0.25 : 0.035))
        material.faceCulling = .none
        geometry.addChild(ModelEntity(mesh: mesh, materials: [material]))
      }
    }
    for i in 0..<3 {
      let tip = result.point(result.vectors[i]) - center
      addLine(-center, tip, radius: 0.018, color: colors[i])
      let handle = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: colors[i])])
      handle.name = "handle-\(i)"
      handle.position = tip
      handle.components.set(InputTargetComponent())
      handle.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.10)]))
      handle.components.set(HoverEffectComponent())
      var accessibility = AccessibilityComponent()
      accessibility.isAccessibilityElement = true
      accessibility.label = "Vector \(["a", "b", "c"][i]) endpoint"
      accessibility.value = "Quarter-grid coordinates \(result.vectors[i][0]), \(result.vectors[i][1]), \(result.vectors[i][2])"
      handle.components.set(accessibility)
      geometry.addChild(handle)
      let text = ModelEntity(mesh: .generateText(["a", "b", "c"][i], extrusionDepth: 0.002,
        font: .systemFont(ofSize: 0.11)), materials: [UnlitMaterial(color: colors[i])])
      text.position = tip + [0.10, 0.09, 0]
      geometry.addChild(text)
    }
    let origin = ModelEntity(mesh: .generateSphere(radius: 0.03), materials: [UnlitMaterial(color: .white)])
    origin.position = -center
    geometry.addChild(origin)
  }

  private func addLine(_ start: SIMD3<Float>, _ end: SIMD3<Float>, radius: Float, color: UIColor) {
    let delta = end - start
    let length = simd_length(delta)
    guard length > 0.00001 else { return }
    let entity = ModelEntity(mesh: .generateCylinder(height: length, radius: radius),
      materials: [UnlitMaterial(color: color)])
    entity.position = (start + end) / 2
    entity.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
    geometry.addChild(entity)
  }
}
