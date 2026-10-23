// SPDX-License-Identifier: GPL-3.0-or-later
// Rendering and once-head placement adapted from FareyVision ca809d2975a37a318a425e4b9dd73560b07faf39,
// Farey/Sources/StarscapeRenderer.swift and FareyImmersiveView.swift.
// Alok Singh with OpenAI Codex, 2026-10-23: consume exact Lean data; all meshes remain approximate.
import RealityKit
import SwiftUI

@MainActor struct PolynomialSpace: View {
  @Environment(PolynomialModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @State private var renderer = PolynomialRenderer()
  @State private var activation: EventSubscription?
  var body: some View {
    RealityView { content, attachments in
      content.add(renderer.stage); content.add(renderer.anchorHost)
      activation = content.subscribe(to: AccessibilityEvents.Activate.self) { [model] event in
        Self.select(event.entity, model: model)
      }
      if let panel = attachments.entity(for: "controls") {
        panel.position = [-0.95, 1.20, -1.65]; panel.scale = [1.15,1.15,1.15]
        content.add(panel)
      }
      renderer.render(model)
    } update: { _, _ in renderer.render(model) }
    attachments: {
      Attachment(id: "controls") {
        PolynomialControls().environment(model).frame(width: 660, height: 900).glassBackgroundEffect()
      }
    }
    .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in Self.select(value.entity, model: model) })
    .onAppear { model.spaceOpen = true }
    .onDisappear {
      activation?.cancel(); activation = nil
      model.spaceOpen = false; model.transitioning = false; model.place(.overview)
      openWindow(id: "polynomial-launch")
    }
  }
  private static func select(_ entity: Entity, model: PolynomialModel) {
    guard model.placement == .overview, !model.busy, model.actionPreview == nil else { return }
    let pieces = entity.name.split(separator: ":")
    guard pieces.count == 4, pieces[0] == "polynomial",
      let a = Int(pieces[1]), let b = Int(pieces[2]), let c = Int(pieces[3]) else { return }
    model.enter([a,b,c])
  }
}

@MainActor final class PolynomialRenderer {
  let stage = Entity(), anchorHost = Entity(), root = Entity()
  private let cloud = Entity(), guides = Entity(), projection = Entity(), selection = Entity(), plane = Entity()
  private let projectionDots = Entity(), projectionGuides = Entity()
  private var headAnchor: AnchorEntity?
  private var placement = PolynomialPlacement.overview
  private var anchorEpoch = -1
  private var cloudKey = "", sceneKey = ""
  private var dots: [String: ModelEntity] = [:]
  private var radialDots: [String: ModelEntity] = [:]
  private var actionRows: [Double] = [1,0,0,0,1,0,0,0,1]
  private var inhabitOffset: SIMD3<Float>?
  private var materials: [UInt32: UnlitMaterial] = [:]
  private let glyph = MeshResource.generateSphere(radius: 0.0075)
  private var scale: Float = 0.16
  init() {
    stage.addChild(root)
    for child in [guides, cloud, projection, plane, selection] { root.addChild(child) }
    projection.addChild(projectionDots); projection.addChild(projectionGuides)
  }

  func render(_ model: PolynomialModel) {
    scale = 0.96 / Float(model.displayedRadius)
    actionRows = model.displayActionRows
    place(model.placement, epoch: model.placementEpoch, viewpoint: model.viewpoint)
    let key = "\(model.displayedRadius)-\(model.points.count)-\(model.colorLower)-\(model.palette)"
    if cloudKey != key {
      cloudKey = key; sceneKey = ""; dots.removeAll(); radialDots.removeAll()
      cloud.children.removeAll(); projectionDots.children.removeAll()
      for p in model.points {
        let dot = ModelEntity(mesh: glyph, materials: [material(PolynomialAppearance.color(p, colorLower: model.colorLower, palette: model.palette))])
        dot.position = p.vector * scale; dot.name = "polynomial:\(p.id)"
        dot.components.set(InputTargetComponent())
        dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.025)]))
        dot.components.set(HoverEffectComponent())
        var accessibility = AccessibilityComponent()
        accessibility.isAccessibilityElement = true; accessibility.traits = [.button]
        accessibility.label = "Polynomial point \(p.abc[0]), \(p.abc[1]), \(p.abc[2]), discriminant \(p.delta)"
        dot.components.set(accessibility)
        dots[p.id] = dot; cloud.addChild(dot)
        if (p.kind == 2 || p.kind == 3), p.xyz[1] != 0 {
          let image = ModelEntity(mesh: glyph, materials: [material(PolynomialAppearance.guide)])
          // Perspective placement from accepted coordinates; this is floating-point renderer behavior.
          image.position = p.vector * (4 * scale / Float(p.xyz[1])); image.scale = .init(repeating: 0.36)
          projectionDots.addChild(image); radialDots[p.id] = image
        }
      }
    }
    projection.isEnabled = model.showProjection
    guides.isEnabled = model.showCone
    let nextScene = "\(model.sceneRevision)-\(model.actionRevision)-\(model.placement.isOrigin)-\(model.placement == .overview)-\(model.colorLower)-\(model.showProjection)-\(model.starSize)-\(model.planeFocus)"
    guard sceneKey != nextScene else { return }
    sceneKey = nextScene
    plane.children.removeAll(); selection.children.removeAll()
    guides.children.removeAll(); projectionGuides.children.removeAll(); cone()
    let focusNormal: SIMD3<Double>? = model.planeFocus ? model.plane.flatMap { cutting in
      let n = cutting.cartesianNormal
      return PolynomialMobius.mapPlaneNormal(rows:actionRows,[Double(n[0]),Double(n[1]),Double(n[2])])
    } : nil
    for p in model.points {
      // Nearby stars must not intercept the panel's indirect selection rays when inhabiting the cloud.
      var target = InputTargetComponent(); target.isEnabled = model.placement == .overview
      dots[p.id]?.components.set(target)
      let original = SIMD3<Double>(Double(p.xyz[0]),Double(p.xyz[1]),Double(p.xyz[2]))
      let displayPosition = PolynomialMobius.mapDisplayCoordinates(rows:actionRows,original) ?? original
      let position = SIMD3<Float>(Float(displayPosition.x),Float(displayPosition.y),Float(displayPosition.z)) * scale
      dots[p.id]?.position = position
      if let radial = radialDots[p.id] {
        radial.isEnabled = abs(position.y) > 0.000001
        if radial.isEnabled { radial.position = position * (4 * scale / position.y) }
      }
      let base = model.placement.isOrigin && p.delta < 0
        ? Float(0.4 * pow(Double(-p.delta),0.25) / sqrt(max(0.000001,Double(abs(position.y/scale)))))
        : PolynomialAppearance.radiusFactor(p,colorLower:model.colorLower,atOrigin:false)
      let factor = Float(model.starSize) * base * (p.necklace && p.kind == 2 && !model.placement.isOrigin ? 1.35 : 1)
      dots[p.id]?.scale = .init(repeating: factor)
      let fade = focusNormal.map {
        PolynomialAppearance.focusFade(p, position:displayPosition, normal:$0, radius:model.displayedRadius, keep:model.inspection?.point ?? [])
      } ?? 1
      dots[p.id]?.model?.materials = [material(PolynomialAppearance.color(p, colorLower: model.colorLower, palette: model.palette) * fade)]
      if p.necklace { marker(at: position, factor: factor * 1.55, rgb: PolynomialAppearance.amber, parent: plane) }
    }
    if let detail = model.inspection {
      let id = detail.point.map(String.init).joined(separator: ":")
      if let dot = dots[id] {
        marker(at: dot.position, factor: dot.scale.x * 1.55, rgb: [1,1,1], parent: selection)
        line(.zero, dot.position, rgb: PolynomialAppearance.selectionRay, alpha: 0.35, parent: selection, transform:false)
      }
      if model.showProjection, detail.projection != nil {
        let image = mapped(SIMD3(Float(detail.xyz[0]),Float(detail.xyz[1]),Float(detail.xyz[2])) * scale)
        if abs(image.y) > 0.000001 {
          let point = image * (4 * scale / image.y)
          line(.zero, point, rgb: [1,1,1], alpha: 1, parent: selection, transform:false)
          marker(at: point, factor: 1.2, rgb: [1,1,1], parent: selection)
        }
      }
    }
    if let cutting = model.plane { drawPlane(cutting, radius: Float(model.displayedRadius), showProjection: model.showProjection) }
    if let second = model.displayedPair, let dot = dots[second.map(String.init).joined(separator: ":")] {
      marker(at: dot.position, factor: dot.scale.x * 1.9, rgb: PolynomialAppearance.amber, parent: plane)
    }
  }

  private func place(_ next: PolynomialPlacement, epoch: Int, viewpoint: Int) {
    let anchored = next != .overview
    if anchored && (headAnchor == nil || anchorEpoch != epoch) {
      headAnchor?.removeFromParent()
      let anchor = AnchorEntity(.head); anchor.anchoring.trackingMode = .once
      anchor.name = "polynomial-head-anchor-once"; anchorHost.addChild(anchor); anchor.addChild(root)
      headAnchor = anchor; anchorEpoch = epoch
      inhabitOffset = nil
    } else if !anchored && headAnchor != nil {
      stage.addChild(root); headAnchor?.removeFromParent(); headAnchor = nil
    }
    placement = next
    switch next {
    case .overview:
      let view = min(2, max(0, viewpoint))
      let yaw: [Float] = [0.4806, 0.4806 + .pi / 3, 0], pitch: [Float] = [0.2814,0.2814,0]
      root.position = [0,1.4,-3.1]
      root.orientation = simd_quatf(angle: pitch[view], axis: [1,0,0]) * simd_quatf(angle: -yaw[view], axis: [0,1,0])
    case .origin(let lower):
      root.position = .zero; root.orientation = simd_quatf(angle: lower ? .pi / 2 : -.pi / 2, axis: [1,0,0])
    case .inhabit(let xyz):
      root.orientation = .init(angle: 0, axis: [0,1,0])
      if inhabitOffset == nil { inhabitOffset = mapped(SIMD3(Float(xyz[0]),Float(xyz[1]),Float(xyz[2])) * scale) }
      root.position = SIMD3<Float>(0,-0.08,-0.35) - (inhabitOffset ?? .zero)
    }
  }

  private func cone() {
    for sign: Float in [1,-1] {
      let ring = (0...64).map { i -> SIMD3<Float> in
        let angle = Float(i) * 2 * .pi / 64
        return [0.96*cos(angle), 0.96*sign, 0.96*sin(angle)]
      }
      // The cone is a fixed reference surface; only the lattice and selected plane move under SL₂.
      fan([.zero] + ring, rgb: PolynomialAppearance.guide, alpha: 0.018, parent: guides, transform:false)
      for i in 0..<64 {
        line(ring[i], ring[i+1], rgb: PolynomialAppearance.guideLine, alpha: 0.26, parent: guides, transform:false)
        if i % 8 == 0 { line(.zero, ring[i], rgb: PolynomialAppearance.guideLine, alpha: 0.26, parent: guides, transform:false) }
      }
    }
    let height = 4 * scale
    let ring = (0...64).map { i -> SIMD3<Float> in
      let angle = Float(i) * 2 * .pi / 64
      return [height*cos(angle),height,height*sin(angle)]
    }
    fan([[0,height,0]] + ring, rgb: PolynomialAppearance.guide, alpha: 0.1, parent: projectionGuides, transform:false)
    for i in 0..<64 { line(ring[i], ring[i+1], rgb: PolynomialAppearance.guide, alpha: 0.8, parent: projectionGuides, transform:false) }
  }

  private func drawPlane(_ cutting: PolynomialPlane, radius: Float, showProjection: Bool) {
    let n = SIMD3<Float>(Float(cutting.cartesianNormal[0]),Float(cutting.cartesianNormal[1]),Float(cutting.cartesianNormal[2]))
    let horizontal = sqrt(n.x*n.x+n.z*n.z), length = simd_length(n)
    guard horizontal > 0, length > 0 else { return }
    let u = SIMD3<Float>(-n.z/horizontal,0,n.x/horizontal)
    let v = SIMD3<Float>(-n.x*n.y/(horizontal*length),horizontal/length,-n.z*n.y/(horizontal*length))
    let boundary = (0...64).map { i -> SIMD3<Float> in
      let angle = Float(i) * 2 * .pi / 64, d = u * cos(angle) + v * sin(angle)
      return d * (radius * scale / max(abs(d.y),sqrt(d.x*d.x+d.z*d.z)))
    }
    fan([.zero] + boundary, rgb: PolynomialAppearance.amber, alpha: 0.045, parent: plane)
    for i in 0..<64 { line(boundary[i], boundary[i+1], rgb: PolynomialAppearance.amber, alpha: 0.35, parent: plane) }
    let directions = cutting.endpoints.map { endpoint -> SIMD3<Float> in
      let value = endpoint.displayValue
      guard value.isFinite else { return [0,1,1] }
      let angle = 2 * atan(value)
      return [Float(sin(angle)),1,Float(-cos(angle))]
    }
    for direction in directions { line(-0.96*direction,0.96*direction,rgb: PolynomialAppearance.amber,alpha:0.7,parent:plane) }
    if showProjection {
      let projected = directions.map { direction -> SIMD3<Float> in
        let image = mapped(direction)
        return image * (4 * scale / max(0.000001,image.y))
      }
      line(projected[0],projected[1],rgb:PolynomialAppearance.amber,alpha:0.9,parent:plane,transform:false)
    }
  }

  private func mapped(_ point: SIMD3<Float>) -> SIMD3<Float> {
    PolynomialMobius.mapDisplay(rows:actionRows,point) ?? point
  }

  private func material(_ rgb: SIMD3<Double>, alpha: Double = 1) -> UnlitMaterial {
    let bytes = (rgb * 255).rounded(.toNearestOrAwayFromZero)
    let key = UInt32(bytes.x) << 16 | UInt32(bytes.y) << 8 | UInt32(bytes.z)
    if alpha == 1, let cached = materials[key] { return cached }
    var material = UnlitMaterial(applyPostProcessToneMap: false)
    material.color = .init(tint: UIColor(red: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    if alpha < 1 { material.blending = .transparent(opacity: .init(floatLiteral: PolynomialAppearance.linearLightOpacity(alpha,color:rgb))) }
    if alpha == 1 { materials[key] = material }
    return material
  }
  private func marker(at point: SIMD3<Float>, factor: Float, rgb: SIMD3<Double>, parent: Entity) {
    var outline = material(rgb); outline.faceCulling = .front
    let entity = ModelEntity(mesh: glyph, materials: [outline]); entity.position = point
    entity.scale = .init(repeating: factor); parent.addChild(entity)
  }
  private func line(_ from: SIMD3<Float>, _ to: SIMD3<Float>, rgb: SIMD3<Double>, alpha: Double, parent: Entity, transform: Bool = true) {
    let a = transform ? mapped(from) : from, b = transform ? mapped(to) : to
    let delta = b-a, length = simd_length(delta)
    guard length > 0.00001 else { return }
    let entity = ModelEntity(mesh: .generateBox(size: [0.002,length,0.002]),materials:[material(rgb,alpha:alpha)])
    entity.position = (a+b)/2; entity.orientation = simd_quatf(from:[0,1,0],to:delta/length)
    parent.addChild(entity)
  }
  private func fan(_ input: [SIMD3<Float>], rgb: SIMD3<Double>, alpha: Double, parent: Entity, transform: Bool = true) {
    let vertices = transform ? input.map(mapped) : input
    var descriptor = MeshDescriptor(name: "Approximate polynomial display surface")
    descriptor.positions = MeshBuffers.Positions(vertices)
    descriptor.primitives = .triangles((1..<(vertices.count-1)).flatMap { [0,UInt32($0),UInt32($0+1)] })
    guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return }
    var material = material(rgb,alpha:alpha); material.faceCulling = .none
    parent.addChild(ModelEntity(mesh:mesh,materials:[material]))
  }
}
