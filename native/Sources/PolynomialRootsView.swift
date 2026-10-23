// SPDX-License-Identifier: GPL-3.0-or-later
// Upper-half-plane presentation adapted from FareyVision 2a0ef3216a931bdcf6cdd9ba89a1baf6f4cfa46a,
// Farey/Sources/RootsPaneView.swift and Farey/WebXR/roots-pane.js, after Katherine Stange's viewer.
// Alok Singh with OpenAI Codex, 2026-10-23. Exact identities/classifications/receipts come from Lean.
import SwiftUI

struct PolynomialRootsView: View {
  @Environment(PolynomialModel.self) private var model
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var viewport: PolynomialRootsGeometry.Viewport?
  @State private var mode = RootsInput.move
  @State private var dragAttempted = false
  @State private var panStart: PolynomialRootsGeometry.Viewport?
  @State private var zoomStart: PolynomialRootsGeometry.Viewport?
  @State private var callbacks = 0
  @State private var releases = 0
  @State private var taps = 0
  @State private var tapText = "No tap received"
  @State private var gestureText = "Drag a root to move the cloud."
  @GestureState private var dragActive = false
  private let diagnostics = ProcessInfo.processInfo.environment["POLYNOMIAL_GESTURE_DIAGNOSTICS"] == "1"
  private enum RootsInput: String, CaseIterable, Identifiable {
    case move = "Move", select = "Select", pair = "Pair", pan = "Pan"
    var id: String { rawValue }
  }

  var body: some View {
    @Bindable var model = model
    VStack(spacing:6) {
      HStack {
        Text("Roots · upper half-plane").font(.headline)
        Spacer()
        PolynomialPairNextButton(identifier:"poly-roots-pair-next")
        Button("Close") {
          model.cancelPairing(); dismissWindow(id:"polynomial-roots")
        }.accessibilityIdentifier("poly-roots-close")
      }
      HStack {
        Picker("Input",selection:inputMode) {
          ForEach(RootsInput.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier("poly-roots-mode")
        Button("−") { zoom(0.8) }.accessibilityLabel("Zoom out").accessibilityIdentifier("poly-roots-zoom-out")
        Button("+") { zoom(1.25) }.accessibilityLabel("Zoom in").accessibilityIdentifier("poly-roots-zoom-in")
        Button("Fit") { fit() }.accessibilityIdentifier("poly-roots-fit")
      }
      if model.pairNext {
        Text("Next pick pairs with (\((model.inspection?.point ?? model.selected).map(String.init).joined(separator:", "))).")
          .font(.caption).foregroundStyle(.orange).frame(maxWidth:.infinity,alignment:.leading)
          .accessibilityIdentifier("poly-roots-pair-next-state")
      }
      GeometryReader { geometry in
        if let frame = viewport?.resized(to:geometry.size) ?? PolynomialRootsGeometry.Viewport(size:geometry.size) {
          let dots = PolynomialRootsGeometry.dots(points:model.renderPoints.filter { model.renderCatalogue == nil || $0.divisor == 1 },rows:model.displayActionRows,viewport:frame,sigma:model.starSize,preservingSourceOrder:model.renderCatalogue != nil)
            .filter { dot in
              guard dot.intersects(frame), let shown = PolynomialMobius.mapDisplayCoordinates(rows:model.displayActionRows,
                SIMD3(Double(dot.point.xyz[0]),Double(dot.point.xyz[1]),Double(dot.point.xyz[2]))) else { return false }
              return PolynomialRenderPlan.catalogueOpacity(point:dot.point,shown:shown,catalogue:model.renderCatalogue) > 0
            }
          Canvas { context, _ in draw(dots,frame:frame,in:&context) }
            .background(.black).clipped().contentShape(Rectangle())
            .accessibilityElement(children:.ignore)
            .accessibilityLabel("Roots of the upper interior forms in the upper half-plane")
            .accessibilityValue(chartValue(frame))
            .accessibilityIdentifier("poly-roots-chart")
            .highPriorityGesture(DragGesture(minimumDistance:4)
              .updating($dragActive) { _, state, _ in state = true }
              .onChanged { value in
                callbacks += 1
                guard !model.busy else { gestureText = "Waiting for Lean · accepted scene retained"; return }
                switch effectiveMode {
                case .move:
                  if !dragAttempted, let start = frame.root(at:value.startLocation) {
                    dragAttempted = true; model.beginRootsDrag(at:start)
                  }
                  if let current = frame.root(at:value.location) { model.updateRootsDrag(to:current) }
                  gestureText = model.actionPreview == nil ? "Above the real axis to move" : "Approximate move preview"
                case .pan:
                  if panStart == nil { panStart = frame; model.hover(nil) }
                  viewport = panStart?.panned(by:value.translation)
                  gestureText = "Chart panned · action unchanged"
                case .select, .pair: break
                }
              }
              .onEnded { value in
                releases += 1
                if effectiveMode == .move, dragAttempted {
                  if let current = frame.root(at:value.location) { model.updateRootsDrag(to:current,force:true) }
                  dragAttempted = false
                  gestureText = model.commitRootsDrag() ? "Released declared sample to Lean" : "No owned valid move sample"
                }
                panStart = nil
              })
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
              taps += 1
              let picked = pickRoot(dots,at:value.location)
              tapText = String(format:"Tap %.2f, %.2f",value.location.x,value.location.y)
                + " · " + (picked?.point.id ?? "no root")
              guard effectiveMode != .pan, !model.busy, model.actionPreview == nil, let dot = picked else { return }
              model.pick(dot.point.abc)
            })
            .simultaneousGesture(MagnifyGesture()
              .onChanged { value in
                guard !dragAttempted else { return }
                if zoomStart == nil { zoomStart = frame; model.hover(nil) }
                viewport = zoomStart?.zoomed(by:Double(value.magnification),at:CGPoint(x:frame.size.width/2,y:frame.size.height/2))
              }
              .onEnded { _ in zoomStart = nil })
            .onContinuousHover { phase in
              guard !dragActive, !dragAttempted, model.actionPreview == nil else { return }
              switch phase {
              case .active(let location): model.hover(pickRoot(dots,at:location)?.point.abc)
              case .ended: model.hover(nil)
              }
            }
            .onAppear { if viewport == nil { viewport = frame } }
            .onChange(of:geometry.size) { _, size in cancelPreview(); model.hover(nil); viewport = viewport?.resized(to:size) }
        }
      }.frame(minHeight:300).layoutPriority(1)
      HStack {
        Button("T") { model.applyGenerator([1,1,0,1]) }.accessibilityIdentifier("poly-roots-t")
        Button("T⁻¹") { model.applyGenerator([1,-1,0,1]) }.accessibilityIdentifier("poly-roots-t-inverse")
        Button("S") { model.applyGenerator([0,-1,1,0]) }.accessibilityIdentifier("poly-roots-s")
        Button("i → 1+i") { model.requestAction([3,1,1,2]) }.accessibilityIdentifier("poly-roots-checkpoint")
        Spacer(minLength:0)
      }.disabled(model.busy || model.actionPreview != nil)
      HStack {
        Button("Snap") { model.snapAction() }.accessibilityIdentifier("poly-roots-snap")
        Button("Identity") { model.requestAction([1,0,0,1]) }.accessibilityIdentifier("poly-roots-identity")
        Button("Reset") { model.reset() }.accessibilityIdentifier("poly-roots-reset")
        Spacer(minLength:0)
        if model.renderCatalogue == nil {
          Toggle("Plane fade",isOn:$model.planeFocus).toggleStyle(.button).font(.caption)
            .disabled(model.plane == nil).accessibilityIdentifier("poly-roots-plane-focus")
        }
      }.disabled(model.busy || model.actionPreview != nil)
      ScrollView {
      VStack(alignment:.leading,spacing:4) {
      if let hover = model.hoverInspection {
        Text("\(hover.displayPolynomial) · (\(hover.point.map(String.init).joined(separator:", "))) · Δ = \(String(hover.delta))")
          .font(.system(size:12,design:.monospaced)).foregroundStyle(.mint).accessibilityIdentifier("poly-roots-hover")
      } else {
        Text(model.hoverStatus.isEmpty ? "Hover a root for its polynomial; tap to select or pair." : model.hoverStatus)
          .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("poly-roots-hover-status")
      }
      if let detail = model.inspection {
        Text("\(detail.displayPolynomial) · (\(detail.point.map(String.init).joined(separator:", "))) · Δ = \(String(detail.delta))")
          .font(.system(size:12,design:.monospaced)).accessibilityIdentifier("poly-roots-selection")
        Text(model.rootReadout).font(.caption.monospaced()).foregroundStyle(.secondary)
          .accessibilityIdentifier("poly-roots-readout")
      }
      Text(model.plane == nil ? "No cutting plane" : model.planeReadout)
        .font(.caption.monospaced()).foregroundStyle(.orange).lineLimit(2)
        .accessibilityIdentifier("poly-roots-plane")
      Text(model.actionStatus).font(.caption).foregroundStyle(model.actionPreview == nil ? Color.mint : Color.orange)
        .accessibilityIdentifier("poly-roots-status")
      if !model.previewCatalogueStatus.isEmpty {
        Text(model.previewCatalogueStatus).font(.caption2).foregroundStyle(.secondary)
          .accessibilityIdentifier("poly-roots-preview-catalogue")
      }
      Text(model.inspection?.kind != "upper" || !model.selectionShown
        ? "Signed selection retained · no dot in this upper-positive crop"
        : "Upper-positive roots · signed base identities retained")
        .font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("poly-roots-crop")
      if diagnostics {
        Text("Changed \(callbacks) · ended \(releases) · \(gestureText)").font(.caption2.monospaced())
          .accessibilityIdentifier("poly-roots-gesture")
        Text("Taps \(taps) · \(tapText)").font(.caption2.monospaced()).accessibilityIdentifier("poly-roots-tap")
        Text("M = [\((model.action?.matrix ?? [1,0,0,1]).map(String.init).joined(separator:", "))]")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-roots-matrix")
        Text("Preview crops accepted: \(model.previewCatalogueAcceptances)")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-roots-preview-count")
        Text(viewport.map { String(format:"Chart center %.4f, %.4f · scale %.4f",$0.center.x,$0.center.y,$0.scale) } ?? "Chart fit")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-roots-viewport")
      }
      if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange) }
      }.frame(maxWidth:.infinity,alignment:.leading)
      }.frame(minHeight:100,idealHeight:140,maxHeight:160)
      Text("Lean: exact signed identities and accepted action. Display and picking: approximate.")
        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
    }.controlSize(.small).padding(12).frame(minWidth:420,minHeight:560).background(.black)
      .onAppear { model.rootsOpen = true; if model.pairNext { mode = .pair } }
      .onDisappear { model.rootsOpen = false; cancelPreview(); model.hover(nil); model.cancelPairing() }
      .onChange(of:mode) { _, _ in cancelPreview(); model.hover(nil) }
      .onChange(of:model.pairNext) { _, armed in
        cancelPreview()
        if armed { mode = .pair }
        else if mode == .pair { mode = .select }
      }
      .onChange(of:model.rootsResetRevision) { _, _ in mode = .move; fit() }
      .onChange(of:dragActive) { _, active in
        if !active {
          Task { @MainActor in
            await Task.yield()
            if !dragActive, dragAttempted { cancelPreview(); gestureText = "Move cancelled · accepted scene retained" }
          }
        }
      }
  }
  private var effectiveMode: RootsInput { model.pairNext ? .pair : mode }
  private var inputMode: Binding<RootsInput> {
    Binding(get:{ effectiveMode },set:{ next in
      cancelPreview(); model.hover(nil)
      if next == .pair {
        model.armPairNext(true)
        mode = model.pairNext ? .pair : .select
      } else {
        // Choosing Select explicitly exits the shared one-shot pairing mode.
        model.cancelPairing(); mode = next
      }
    })
  }
  private func cancelPreview() {
    if dragAttempted { model.cancelRootsDrag() }
    dragAttempted = false; panStart = nil; zoomStart = nil
  }
  private func chartValue(_ frame:PolynomialRootsGeometry.Viewport) -> String {
    let status = model.actionPreview != nil ? "Approximate move preview" : (model.action?.matrix ?? [1,0,0,1]) == [1,0,0,1] ? "g = identity" : "g moved"
    guard diagnostics, let unit = frame.screen([0,1]), let pair = frame.screen([-0.5,sqrt(3)/2]) else { return status }
    let object:[String:Any] = ["state":status,"size":[frame.size.width,frame.size.height],
      "unit":[unit.x/frame.size.width,unit.y/frame.size.height],"pair":[pair.x/frame.size.width,pair.y/frame.size.height]]
    guard let data = try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys),
      let text = String(data:data,encoding:.utf8) else { return status }
    return text
  }
  private func fit() {
    cancelPreview(); model.hover(nil)
    if let viewport { self.viewport = PolynomialRootsGeometry.Viewport(size:viewport.size) }
  }
  private func zoom(_ factor:Double) {
    guard let viewport else { return }
    cancelPreview(); model.hover(nil)
    self.viewport = viewport.zoomed(by:factor,at:CGPoint(x:viewport.size.width/2,y:viewport.size.height/2))
  }
  private func pickRoot(_ dots:[PolynomialRootsGeometry.Dot],at location:CGPoint) -> PolynomialRootsGeometry.Dot? {
    guard let catalogue = model.renderCatalogue else { return PolynomialRootsGeometry.pick(dots,at:location) }
    let rows = model.displayActionRows
    return PolynomialRootsGeometry.pickSource(dots,at:location,hasPlane:model.plane != nil) { dot in
      let xyz = dot.point.xyz
      guard let shown = PolynomialMobius.mapDisplayCoordinates(rows:rows,SIMD3(Double(xyz[0]),Double(xyz[1]),Double(xyz[2]))) else { return 0 }
      return PolynomialRenderPlan.catalogueOpacity(point:dot.point,shown:shown,catalogue:catalogue)
    }
  }
  private func draw(_ dots:[PolynomialRootsGeometry.Dot],frame:PolynomialRootsGeometry.Viewport,in context:inout GraphicsContext) {
    let rows = model.displayActionRows
    let sourceMode = model.renderCatalogue != nil
    let normal:SIMD3<Double>? = !sourceMode && model.planeFocus ? model.plane.flatMap {
      PolynomialMobius.mapPlaneNormal(rows:rows,SIMD3(Double($0.cartesianNormal[0]),Double($0.cartesianNormal[1]),Double($0.cartesianNormal[2])))
    } : nil
    if let plane = model.plane {
      let endpoints = plane.endpoints.compactMap { PolynomialMobius.actReal(model.displayActionMatrix,$0.displayValue) }
      let samples = PolynomialRootsGeometry.geodesic(endpoints:endpoints,viewport:frame)
      if let first = samples.first {
        context.stroke(Path { p in p.move(to:first); for next in samples.dropFirst() { p.addLine(to:next) } },
          with:.color(.orange.opacity(0.65)),lineWidth:1.2)
      }
    }
    for dot in dots where dot.isDrawable {
      let rgb = PolynomialAppearance.color(dot.point,colorLower:model.colorLower,palette:model.palette)
      let radius = dot.drawnRadius
      let p = dot.point, xyz = SIMD3(Double(p.xyz[0]),Double(p.xyz[1]),Double(p.xyz[2]))
      let position = PolynomialMobius.mapDisplayCoordinates(rows:rows,xyz) ?? xyz
      let crop = PolynomialRenderPlan.catalogueOpacity(point:p,shown:position,catalogue:model.renderCatalogue)
      if sourceMode {
        context.opacity = PolynomialRootsGeometry.sourceBodyOpacity(dot,crop:crop,hasPlane:model.plane != nil)
      } else {
        let fade = normal.map { PolynomialAppearance.focusFade(p,position:position,normal:$0,radius:model.displayedRadius,keep:model.inspection?.point ?? []) } ?? 1
        context.opacity = dot.opacity * fade * crop
      }
      let bounds = CGRect(x:dot.center.x-radius,y:dot.center.y-radius,width:2*radius,height:2*radius)
      context.fill(dot.radius < 1.5 ? Path(bounds) : Path(ellipseIn:bounds),
        with:.color(Color(red:rgb.x,green:rgb.y,blue:rgb.z)))
    }
    context.opacity = 1
    if let axis = frame.screen([0,0])?.y {
      context.stroke(Path { p in p.move(to:CGPoint(x:0,y:axis));p.addLine(to:CGPoint(x:frame.size.width,y:axis)) },
        with:.color(Color(red:0.47,green:0.59,blue:0.66)),lineWidth:1)
      for (t,label) in [(-1.0,"−1"),(-0.5,"−½"),(0,"0"),(0.5,"½"),(1,"1")] {
        if let p = frame.screen([t,0]) { context.draw(Text(label).font(.caption2).foregroundStyle(.secondary),at:CGPoint(x:p.x,y:axis+14)) }
      }
    }
    if sourceMode {
      for (detail,color) in [(model.inspection,Color.white),(model.pairedInspection,Color.orange)] {
        guard let detail, let dot = PolynomialRootsGeometry.sourceSelectionRing(inspection:detail,
          rows:rows,viewport:frame,sigma:model.starSize) else { continue }
        drawRing(dot,radius:dot.sourceRingRadius,label:detail.displayPolynomial,color:color,frame:frame,in:&context)
      }
      if let point = model.hoveredPoint, point != model.inspection?.point, point != model.displayedPair,
        let dot = dots.first(where:{ $0.point.abc == point }) {
        context.opacity = 0.55
        drawRing(dot,radius:dot.sourceRingRadius,label:model.polynomialLabel(for:point),color:.mint,frame:frame,in:&context)
        context.opacity = 1
      }
    } else {
      for (point,color) in [(model.inspection?.point,Color.white),(model.displayedPair,Color.orange),(model.hoveredPoint,Color.mint)] {
        guard let point, let dot = dots.first(where: { $0.point.abc == point }) else { continue }
        drawRing(dot,radius:dot.ringRadius,label:model.polynomialLabel(for:point),color:color,frame:frame,in:&context)
      }
    }
  }
  private func drawRing(_ dot:PolynomialRootsGeometry.Dot,radius:Double,label:String?,color:Color,
    frame:PolynomialRootsGeometry.Viewport,in context:inout GraphicsContext) {
    context.stroke(Path(ellipseIn:CGRect(x:dot.center.x-radius,y:dot.center.y-radius,width:2*radius,height:2*radius)),with:.color(color),lineWidth:1.2)
    if let label {
      let text = context.resolve(Text(label).font(.system(size:12,design:.monospaced)).foregroundStyle(color))
      let width = text.measure(in:CGSize(width:CGFloat.infinity,height:CGFloat.infinity)).width
      if let position = dot.labelPosition(textWidth:width,in:frame) { context.draw(text,at:position,anchor:.leading) }
    }
  }
}
