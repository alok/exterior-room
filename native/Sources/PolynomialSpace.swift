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
    .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
      guard model.placement == .overview, !model.busy, model.actionPreview == nil else { return }
      if let point = renderer.pick(value.convert(value.location3D,from:.local,to:renderer.root),entity:value.entity,revision:model.sceneRevision) {
        model.enter(point.abc)
      } else { Self.select(value.entity,model:model) }
    })
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
  private let cloud = Entity(), guides = Entity(), projection = Entity(), selection = Entity(), plane = Entity(), picking = Entity()
  private let projectionDots = Entity(), projectionGuides = Entity()
  private var headAnchor: AnchorEntity?
  private var placement = PolynomialPlacement.overview
  private var anchorEpoch = -1
  private var sceneKey = ""
  private var renderingFailed = false, guideRadius = -1
  private var actionRows: [Double] = [1,0,0,0,1,0,0,0,1]
  private var inhabitOffset: SIMD3<Float>?
  private var materials: [UInt32: UnlitMaterial] = [:]
  private let glyph: MeshResource
  private var batches:[UInt32:InstanceBatch] = [:]
  private var radialBatch:InstanceBatch?
  private var scale: Float = 0.16
  private var collisionTask:Task<Void,Never>?
  private var collisionGeneration = 0, collisionRevision = -1
  private var collisionKey = "", requestedCollisionKey = ""
  private var collisionSnapshot:PolynomialRenderPlan.Snapshot?
  private var collisionRanges:[String:Range<Int>] = [:]

  @MainActor private final class InstanceBatch {
    let entity:ModelEntity, data:LowLevelInstanceData
    init(mesh:MeshResource,material:UnlitMaterial,count:Int) throws {
      data = try LowLevelInstanceData(instanceCount:count,instanceCapacity:max(1,count*2))
      entity = ModelEntity(mesh:mesh,materials:[material])
    }
    func update(mesh:MeshResource,positions:[SIMD3<Float>],factors:[Float]) throws {
      data.instanceCount = positions.count
      var minimum = SIMD3<Float>(repeating:.infinity),maximum = SIMD3<Float>(repeating:-.infinity)
      data.withMutableTransforms { buffer in
        for i in positions.indices {
          buffer[i] = Transform(scale:SIMD3(repeating:factors[i]),translation:positions[i]).matrix
          let radius = SIMD3<Float>(repeating:0.0075*factors[i])
          minimum = simd_min(minimum,positions[i]-radius); maximum = simd_max(maximum,positions[i]+radius)
        }
      }
      entity.components.set(try MeshInstancesComponent(mesh:mesh,instances:data,bounds:BoundingBox(min:minimum,max:maximum)))
    }
  }
  init() {
    let sphere = PolynomialRenderPlan.sphere()
    var descriptor = MeshDescriptor(name:"Shared approximate polynomial glyph")
    descriptor.positions = MeshBuffers.Positions(sphere.positions); descriptor.primitives = .triangles(sphere.indices)
    glyph = (try? MeshResource.generate(from:[descriptor])) ?? MeshResource.generateSphere(radius:0.0075)
    stage.addChild(root)
    for child in [guides,cloud,projection,plane,selection,picking] { root.addChild(child) }
    projection.addChild(projectionDots); projection.addChild(projectionGuides)
  }

  func render(_ model: PolynomialModel) {
    scale = 0.96 / Float(model.displayedRadius)
    actionRows = model.displayActionRows
    place(model.placement,epoch:model.placementEpoch,viewpoint:model.viewpoint)
    projection.isEnabled = model.showProjection; guides.isEnabled = model.showCone
    picking.isEnabled = model.placement == .overview && !model.busy && model.actionPreview == nil
      && collisionRevision == model.sceneRevision && !renderingFailed
    let nextScene = "\(model.sceneRevision)-\(model.actionRevision)-\(model.placement.isOrigin)-\(model.placement == .overview)-\(model.colorLower)-\(model.palette)-\(model.showProjection)-\(model.starSize)-\(model.planeFocus)"
    guard sceneKey != nextScene else { return }
    let started = Date.timeIntervalSinceReferenceDate
    let focusNormal:SIMD3<Double>? = model.planeFocus ? model.plane.flatMap { cutting in
      let n = cutting.cartesianNormal
      return PolynomialMobius.mapPlaneNormal(rows:actionRows,[Double(n[0]),Double(n[1]),Double(n[2])])
    } : nil
    guard let snapshot = PolynomialRenderPlan.make(points:model.points,rows:actionRows,radius:model.displayedRadius,
      origin:model.placement.isOrigin,starSize:model.starSize,colorLower:model.colorLower,palette:model.palette,
      normal:focusNormal,keep:model.inspection?.point ?? [],projection:model.showProjection,catalogue:model.catalogue) else {
        renderFailure("Invalid display coordinates",model:model); return
      }
    do {
      for key in Array(batches.keys) where snapshot.batches[key] == nil {
        batches.removeValue(forKey:key)?.entity.removeFromParent()
      }
      for (key,indices) in snapshot.batches {
        var batch = batches[key]
        if batch == nil || batch!.data.instanceCapacity < indices.count {
          batch?.entity.removeFromParent()
          batch = try InstanceBatch(mesh:glyph,material:material(PolynomialRenderPlan.color(key)),count:indices.count)
          batches[key] = batch; cloud.addChild(batch!.entity)
        }
        try batch!.update(mesh:glyph,positions:indices.map { snapshot.glyphs[$0].position },factors:indices.map { snapshot.glyphs[$0].factor })
      }
      if model.showProjection, !snapshot.radialPositions.isEmpty {
        if radialBatch == nil || radialBatch!.data.instanceCapacity < snapshot.radialPositions.count {
          radialBatch?.entity.removeFromParent()
          radialBatch = try InstanceBatch(mesh:glyph,material:material(PolynomialAppearance.guide),count:snapshot.radialPositions.count)
          projectionDots.addChild(radialBatch!.entity)
        }
        try radialBatch!.update(mesh:glyph,positions:snapshot.radialPositions,factors:Array(repeating:0.36,count:snapshot.radialPositions.count))
      } else { radialBatch?.entity.removeFromParent(); radialBatch = nil }
    } catch {
      renderFailure(error.localizedDescription,model:model)
      return
    }
    cloud.isEnabled = true; plane.isEnabled = true; selection.isEnabled = true
    renderingFailed = false
    // Fixed reference guides do not rebuild for every action or selection.
    if guideRadius != model.displayedRadius {
      guides.children.removeAll(); projectionGuides.children.removeAll(); cone(); guideRadius = model.displayedRadius
    }
    plane.children.removeAll(); selection.children.removeAll()
    for entry in snapshot.glyphs where entry.point.necklace && entry.opacity > 0 {
      marker(at:entry.position,factor:entry.factor*1.55,rgb:PolynomialAppearance.amber,parent:plane)
    }
    if let detail = model.inspection {
      if let entry = snapshot.glyphs.first(where: { $0.point.abc == detail.point && $0.opacity > 0 }) {
        marker(at:entry.position,factor:entry.factor*1.55,rgb:[1,1,1],parent:selection)
        line(.zero,entry.position,rgb:PolynomialAppearance.selectionRay,alpha:0.35,parent:selection,transform:false)
      }
      if model.showProjection,detail.projection != nil {
        let image = mapped(SIMD3(Float(detail.xyz[0]),Float(detail.xyz[1]),Float(detail.xyz[2])) * scale)
        if abs(image.y)>0.000001 {
          let point = image*(4*scale/image.y)
          line(.zero,point,rgb:[1,1,1],alpha:1,parent:selection,transform:false)
          marker(at:point,factor:1.2,rgb:[1,1,1],parent:selection)
        }
      }
    }
    if let cutting = model.plane { drawPlane(cutting,radius:Float(model.displayedRadius),showProjection:model.showProjection) }
    if let second = model.displayedPair,let entry = snapshot.glyphs.first(where: { $0.point.abc == second && $0.opacity > 0 }) {
      marker(at:entry.position,factor:entry.factor*1.9,rgb:PolynomialAppearance.amber,parent:plane)
    }
    sceneKey = nextScene
    let milliseconds = (Date.timeIntervalSinceReferenceDate-started)*1000
    let summary = "\(snapshot.batches.values.reduce(0) { $0+$1.count }) instances · \(snapshot.glyphs.count) buffered · \(batches.count) color batches · \(snapshot.radialPositions.count) projected · \(snapshot.glyphs.filter { $0.point.necklace && $0.opacity > 0 }.count) plane rings · \(String(format:"%.1f",milliseconds)) ms update"
    if model.actionPreview == nil {
      print("POLYNOMIAL_RENDER_STATS: \(summary)")
      Task { @MainActor in model.rendererStats = summary }
      let key = "\(model.sceneRevision)-\(model.starSize)-\(model.placement.isOrigin)-\(model.colorLower)"
      schedulePicking(snapshot,model:model,key:key)
    }
  }
  private func renderFailure(_ message:String,model:PolynomialModel) {
    sceneKey = ""; renderingFailed = true
    cloud.isEnabled = false; projection.isEnabled = false; plane.isEnabled = false; selection.isEnabled = false; picking.isEnabled = false
    let status = "Instance rendering unavailable: \(message)"
    if model.rendererStats != status { Task { @MainActor in model.rendererStats = status } }
  }
  func pick(_ location:SIMD3<Float>,entity:Entity,revision:Int) -> PolynomialPoint? {
    guard !renderingFailed, revision == collisionRevision,let range = collisionRanges[entity.name] else { return nil }
    return collisionSnapshot?.pick(at:location,range:range)
  }
  private func schedulePicking(_ snapshot:PolynomialRenderPlan.Snapshot,model:PolynomialModel,key:String) {
    guard key != collisionKey,key != requestedCollisionKey else { return }
    requestedCollisionKey = key; collisionTask?.cancel(); collisionGeneration += 1
    let version = collisionGeneration,revision = model.sceneRevision
    picking.children.removeAll(); collisionRanges = [:]; collisionSnapshot = nil; collisionRevision = -1; collisionKey = ""
    collisionTask = Task {
      let chunks = PolynomialRenderPlan.collisionChunks(snapshot)
      var ready:[Entity] = [],ranges:[String:Range<Int>] = [:]
      do {
        for (index,chunk) in chunks.enumerated() {
          try Task.checkCancellation()
          guard !chunk.indices.isEmpty else { continue }
          let shape = try await ShapeResource.generateStaticMesh(positions:chunk.positions,faceIndices:chunk.indices)
          let entity = Entity(); entity.name = "polynomial-batch:\(version):\(index)"
          entity.components.set(CollisionComponent(shapes:[shape])); entity.components.set(InputTargetComponent())
          ready.append(entity); ranges[entity.name] = chunk.range
        }
        guard !Task.isCancelled,version == collisionGeneration,revision == model.sceneRevision,
          key == "\(model.sceneRevision)-\(model.starSize)-\(model.placement.isOrigin)-\(model.colorLower)" else { return }
        for entity in ready { picking.addChild(entity) }
        collisionSnapshot = snapshot; collisionRanges = ranges; collisionRevision = revision; collisionKey = key
        requestedCollisionKey = ""
        picking.isEnabled = model.placement == .overview && !model.busy && model.actionPreview == nil && !renderingFailed
        print("POLYNOMIAL_PICKING_READY: \(snapshot.glyphs.count) identities · \(ready.count) collision chunks")
      } catch {
        if version == collisionGeneration { requestedCollisionKey = "" }
      }
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
