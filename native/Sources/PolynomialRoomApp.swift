// SPDX-License-Identifier: GPL-3.0-or-later
// Independent Lean-driven route. Placement/control patterns adapted from FareyVision ca809d2975a37a318a425e4b9dd73560b07faf39.
// Alok Singh with OpenAI Codex, 2026-10-23.
import SwiftUI

@main struct PolynomialRoomApp: App {
  @State private var model = PolynomialModel()
  var body: some Scene {
    Window("Lean Starscape", id: "polynomial-launch") { PolynomialControls().environment(model) }
      .defaultSize(width: 660,height: 900)
      .defaultWindowPlacement { _, _ in WindowPlacement() }
    Window("Roots · Lean Starscape",id:"polynomial-roots") { PolynomialRootsView().environment(model) }
      .defaultSize(width:500,height:660)
      .windowResizability(.contentMinSize)
      .defaultWindowPlacement { _, context in
        let size = CGSize(width:500,height:660)
        if let launch = context.windows.first(where: { $0.id == "polynomial-launch" }) {
          return WindowPlacement(.trailing(launch),size:size)
        }
        // An immersive attachment is not a WindowProxy. The ordinary default keeps
        // this compact window framed; the utility-panel default placed it below the capture.
        return WindowPlacement(size:size)
      }
      .defaultLaunchBehavior(.suppressed).restorationBehavior(.disabled)
    ImmersiveSpace(id: "polynomial-space") { PolynomialSpace().environment(model) }
      .immersionStyle(selection: .constant(.full),in: .full)
  }
}

struct PolynomialControls: View {
  @Environment(PolynomialModel.self) private var model
  @Environment(\.openImmersiveSpace) private var openSpace
  @Environment(\.dismissImmersiveSpace) private var dismissSpace
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var entry = "1, -1, 2"
  @State private var secondEntry = "1, 1, 1"
  @State private var collapsed = false
  @State private var transforms = false

  var body: some View {
    @Bindable var model = model
    ScrollView {
    VStack(alignment: .leading,spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading,spacing: 4) {
          Text("LEAN STARSCAPE").font(.caption.bold()).tracking(4).foregroundStyle(.mint)
          Text("Signed forms. Exact structure.").font(.system(size: 27,weight:.light,design:.serif))
        }
        Spacer()
        Button(model.spaceOpen ? "Leave" : "Enter space",action: toggleSpace)
          .buttonStyle(.borderedProminent).tint(.mint).disabled(model.transitioning || model.points.isEmpty)
          .accessibilityIdentifier("poly-space")
      }
      Text(model.status).font(.caption).foregroundStyle(model.busy ? Color.secondary : Color.mint)
        .accessibilityIdentifier("poly-status")
      if let detail = model.inspection {
        Text(detail.displayPolynomial).font(.system(size: 33,weight:.medium,design:.serif))
          .accessibilityIdentifier("poly-polynomial")
        Text("(\(detail.point.map(String.init).joined(separator: ", "))) · Δ = \(String(detail.delta))")
          .font(.body.monospaced()).accessibilityIdentifier("poly-state")
        Text(model.rootReadout).font(.caption.monospaced()).foregroundStyle(.secondary)
          .accessibilityIdentifier("poly-root")
        if !model.selectionShown {
          Text("Selection retained · hidden by this crop or filter")
            .font(.caption).foregroundStyle(.orange).accessibilityIdentifier("poly-hidden")
        }
      }
      HStack {
        Button("Overview") { model.place(.overview) }.accessibilityIdentifier("poly-overview")
        Button("Origin") { model.place(.origin(lower:false)) }.accessibilityIdentifier("poly-origin")
        Button("Inhabit") {
          if let xyz = model.inspection?.xyz { model.place(.inhabit(xyz:xyz)) }
        }.disabled(model.inspection == nil || !model.selectionShown).accessibilityIdentifier("poly-inhabit")
        Spacer()
        Button("Reset") { model.reset() }.accessibilityIdentifier("poly-reset")
      }
      if case .origin(let lower) = model.placement {
        Button(lower ? "Face upper nappe" : "Face lower nappe") { model.flipOriginNappe() }
          .accessibilityIdentifier("poly-flip-nappe")
      }
      Text(placementText).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("poly-placement")
      if model.placement != .overview {
        Text(model.devicePoseStatus).font(.caption2).foregroundStyle(model.currentDevicePose == nil ? Color.orange:Color.secondary)
          .accessibilityIdentifier("poly-device-pose")
      }
      if ProcessInfo.processInfo.environment["POLYNOMIAL_GESTURE_DIAGNOSTICS"] == "1" {
        Text("Spatial target \(model.spatialTargetReady ? "ready":"pending") · changed \(model.spatialInputCallbacks) · ended \(model.spatialInputReleases) · \(model.spatialInputStatus)")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-spatial-diagnostic")
        Text("Sphere taps \(model.spatialTapCallbacks) · collision revision \(model.spatialPickReadyRevision)")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-spatial-pick-state")
          .accessibilityValue(model.spatialPickJSON)
        Text("Spatial input trace").font(.caption2).accessibilityIdentifier("poly-spatial-pick-trace")
          .accessibilityValue(model.previewTraceJSON)
      }
      HStack {
        Button("Roots…") { openWindow(id:"polynomial-roots") }.accessibilityIdentifier("poly-roots-open")
        Button(transforms ? "Point controls" : "SL₂ transform") { transforms.toggle() }
          .accessibilityIdentifier("poly-action-mode")
        Spacer(minLength:4)
        PolynomialPairNextButton(identifier:"poly-pair-next")
      }
      if model.pairNext {
        Text("Next pick pairs with (\((model.inspection?.point ?? model.selected).map(String.init).joined(separator:", "))).")
          .font(.caption).foregroundStyle(.orange).accessibilityIdentifier("poly-pair-next-state")
      }
      if !transforms, model.action != nil {
        Text(model.actionStatus).font(.caption2).foregroundStyle(.mint)
      }
      if transforms { PolynomialTransformControls().environment(model) }
      if !collapsed && !transforms {
        Divider()
        HStack {
          Picker("Catalogue",selection:Binding(get:{model.catalogueMode},set:{ next in
            if next == .source, model.catalogueMode == .ball, model.radius < 16 { model.radius = 16 }
            model.catalogueMode = next; model.refresh()
          })) {
            Text("Canonical ball").tag(PolynomialCatalogueMode.ball)
            Text("Source depth").tag(PolynomialCatalogueMode.source)
          }.pickerStyle(.segmented).accessibilityIdentifier("poly-catalogue").disabled(model.busy)
          if model.catalogueMode == .source {
            Toggle("Whole",isOn:Binding(get:{model.whole},set:{model.whole=$0;model.refresh()}))
              .toggleStyle(.button).disabled(model.busy).accessibilityIdentifier("poly-whole")
            Toggle("Dust",isOn:Binding(get:{model.dust},set:{model.dust=$0;model.refresh()}))
              .toggleStyle(.button).disabled(model.busy || model.whole).accessibilityIdentifier("poly-dust")
          }
        }
        HStack {
          TextField("a, b, c",text:$entry).textFieldStyle(.roundedBorder).accessibilityIdentifier("poly-entry")
          Button("Select") {
            if let p = parse(entry) { model.cancelPairing(); model.enter(p) }
          }.disabled(model.busy).accessibilityIdentifier("poly-select")
        }
        HStack {
          Button("Next") { model.nextCoefficient() }.disabled(model.busy).accessibilityIdentifier("poly-next")
          Button("Upper") { choose([1,0,1]) }.accessibilityIdentifier("poly-upper")
          Button("Lower") { choose([-1,0,-1]) }.accessibilityIdentifier("poly-lower")
          Button("Exterior") { choose([1,0,-1]) }.accessibilityIdentifier("poly-exterior")
          Spacer()
          Button("R\(model.radius)") {
            let values = [4,6,8,10,12,16,24], index = values.firstIndex(of:model.radius) ?? 1
            model.radius = values[(index+1)%values.count]; model.refresh()
          }.disabled(model.busy).accessibilityIdentifier("poly-radius")
          Toggle("Dense · 24",isOn:Binding(get:{ model.radius == 24 },set:{ model.radius = $0 ? 24 : 6; model.refresh() }))
            .toggleStyle(.button).accessibilityIdentifier("poly-dense")
        }
        HStack {
          TextField("Pair with a, b, c",text:$secondEntry).textFieldStyle(.roundedBorder).accessibilityIdentifier("poly-pair-entry")
          Button("Pair") { if let p = parse(secondEntry) { model.enter(p,asPair:true) } }
            .disabled(model.busy)
            .accessibilityIdentifier("poly-pair")
          Button("Clear") { model.select(model.selected) }.disabled(model.paired == nil).accessibilityIdentifier("poly-clear-pair")
        }
        HStack {
          Toggle("Upper only",isOn:Binding(get:{model.upperOnly},set:{model.upperOnly=$0;model.refresh()}))
            .disabled(model.busy || model.catalogueMode == .source)
            .accessibilityIdentifier("poly-upper-only")
          Toggle("Color lower",isOn:$model.colorLower).accessibilityIdentifier("poly-color-lower")
        }.font(.caption)
        HStack {
          Button(model.palette == "viridis" ? "Colors: Viridis" : "Colors: Stange") {
            model.palette = model.palette == "viridis" ? "reference" : "viridis"
          }.accessibilityIdentifier("poly-palette")
          Text("Size").font(.caption)
          Button("−") { model.starSize = max(0.4,model.starSize-0.1) }
            .accessibilityLabel("Smaller stars").accessibilityIdentifier("poly-size-down")
          Slider(value:$model.starSize,in:0.4...2.5,step:0.05).accessibilityIdentifier("poly-size")
          Button("+") { model.starSize = min(2.5,model.starSize+0.1) }
            .accessibilityLabel("Larger stars").accessibilityIdentifier("poly-size-up")
          Text(model.starSize,format:.number.precision(.fractionLength(2))).font(.caption.monospacedDigit())
            .accessibilityIdentifier("poly-size-value")
        }
        HStack {
          if model.catalogueMode == .source {
            Button(model.showProjection ? "Lift" : "Project") {
              model.setProjection(!model.showProjection,reducedMotion:reduceMotion)
            }.accessibilityIdentifier("poly-projection")
          } else {
            Toggle("Projection",isOn:$model.showProjection).toggleStyle(.button).accessibilityIdentifier("poly-projection")
          }
          Button(["Oblique","Other side","Side view"][model.viewpoint]) { model.viewpoint = (model.viewpoint+1)%3 }
            .disabled(model.placement != .overview).accessibilityIdentifier("poly-view")
          Spacer()
          Text("\(String(model.points.count)) signed triples · \(model.catalogue == nil ? "R" : "depth ")\(model.displayedRadius)")
            .font(.caption).accessibilityIdentifier("poly-count")
        }
        if model.catalogueMode == .source {
          HStack {
            Text("Morph").font(.caption).frame(width:48,alignment:.leading)
            Button("−") { model.setProjectionProgress(model.projectionProgress-0.25) }
              .accessibilityLabel("Less projection").accessibilityIdentifier("poly-projection-down")
            Slider(value:Binding(get:{model.projectionProgress},set:{model.setProjectionProgress($0)}),in:0...1)
              .accessibilityLabel("Projection progress").accessibilityIdentifier("poly-projection-progress")
            Button("+") { model.setProjectionProgress(model.projectionProgress+0.25) }
              .accessibilityLabel("More projection").accessibilityIdentifier("poly-projection-up")
            Text(model.projectionProgress,format:.percent.precision(.fractionLength(0)))
              .font(.caption.monospacedDigit()).frame(width:42,alignment:.trailing)
              .accessibilityIdentifier("poly-projection-value")
          }
          HStack {
            Text("Height").font(.caption).frame(width:48,alignment:.leading)
            Button("−") { model.projectionHeightFraction = max(0.15,model.projectionHeightFraction-0.05) }
              .accessibilityLabel("Lower projection plane").accessibilityIdentifier("poly-projection-height-down")
            Slider(value:$model.projectionHeightFraction,in:0.15...1,step:0.05)
              .accessibilityLabel("Projection height as a fraction of depth").accessibilityIdentifier("poly-projection-height")
            Button("+") { model.projectionHeightFraction = min(1,model.projectionHeightFraction+0.05) }
              .accessibilityLabel("Raise projection plane").accessibilityIdentifier("poly-projection-height-up")
            Text(model.projectionHeightFraction,format:.percent.precision(.fractionLength(0)))
              .font(.caption.monospacedDigit()).frame(width:42,alignment:.trailing)
              .accessibilityIdentifier("poly-projection-height-value")
          }
          Toggle("Projection screen",isOn:$model.showSourceScreen).toggleStyle(.button).font(.caption)
            .accessibilityIdentifier("poly-projection-screen")
        }
        HStack {
          Toggle("Cone",isOn:$model.showCone).toggleStyle(.button).accessibilityIdentifier("poly-cone")
          Toggle("Plane fade",isOn:$model.planeFocus).toggleStyle(.button)
            .disabled(model.plane == nil).accessibilityIdentifier("poly-plane-focus")
        }.font(.caption)
      }
      if model.plane != nil {
        Text(model.planeReadout)
          .font(.caption.monospaced()).foregroundStyle(.orange).accessibilityIdentifier("poly-plane")
        Text("\(model.points.filter(\.necklace).count) buffered interior triples on the plane")
          .font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("poly-members")
      }
      if let catalogue = model.catalogue {
        Text("Source crop previews during movement · release accepts exact state · \(catalogue.complete ? "complete within source bounds" : "source limit reached") · roots show primitive upper forms")
          .font(.caption2).foregroundStyle(catalogue.complete ? Color.secondary : Color.orange).accessibilityIdentifier("poly-catalogue-status")
      }
      Text(model.rendererStats).font(.caption2.monospaced()).foregroundStyle(.secondary).accessibilityIdentifier("poly-render-stats")
      HStack {
        TextField("Mac Lean bridge",text:$model.server).textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("poly-url")
        Button(model.busy ? "Computing…" : "Connect") { model.refresh() }.disabled(model.busy)
          .accessibilityIdentifier("poly-connect")
      }
      HStack {
        Text("\(model.source). Exact: Lean. Meshes, color and placement: RealityKit.")
          .font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("poly-boundary")
        Spacer()
        Button(collapsed ? "More" : "Less") { collapsed.toggle() }.font(.caption)
      }
      if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("poly-error") }
      Text("Visualization after Katherine Stange · independent Lean adaptation")
        .font(.caption2).foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }.padding(20)
    }
      .onChange(of:model.inspection?.point) { _, point in
        if let point { entry = point.map(String.init).joined(separator:", ") }
      }
  }
  private var placementText: String {
    switch model.placement {
    case .overview: "Overview · stationary object"
    case .origin: model.currentDevicePose == nil
      ? "Origin · temporary head placement · spatial drag unavailable"
      : "Origin · fixed at the sampled device pose · move the forms by dragging"
    case .inhabit: model.currentDevicePose == nil
      ? "Inhabit · temporary head placement · device pose pending"
      : "Inhabit · fixed 35 cm ahead of the sampled device pose"
    }
  }
  private func choose(_ point: [Int]) { entry = point.map(String.init).joined(separator:", "); model.select(point) }
  private func parse(_ value: String) -> [Int]? {
    let tokens = value.split { $0 == "," || $0.isWhitespace }, numbers = tokens.compactMap { Int($0) }
    guard tokens.count == 3, numbers.count == 3 else { model.error = "Enter three integers: a, b, c."; return nil }
    return numbers
  }
  private func toggleSpace() {
    model.transitioning = true
    Task { @MainActor in
      defer { model.transitioning = false }
      if model.spaceOpen {
        model.cancelPairing()
        openWindow(id:"polynomial-launch"); await Task.yield(); await dismissSpace()
      } else {
        switch await openSpace(id:"polynomial-space") {
        case .opened: model.spaceOpen = true; dismissWindow(id:"polynomial-launch")
        case .userCancelled: model.error = "Space entry cancelled."
        case .error: model.error = "The immersive space could not open."
        @unknown default: model.error = "Unknown immersive-space result."
        }
      }
    }
  }
}

/// The controls window, immersive controls and Roots window share one armed pick.
struct PolynomialPairNextButton: View {
  @Environment(PolynomialModel.self) private var model
  let identifier: String
  var body: some View {
    Button(model.pairNext ? "Cancel" : "Pair next") {
      if model.pairNext { model.cancelPairing() } else { model.armPairNext(true) }
    }
    .tint(model.pairNext ? .orange : .mint)
    .disabled(!model.pairNext && (model.busy || model.actionPreview != nil))
    .accessibilityLabel(model.pairNext ? "Cancel pairing" : "Pair next")
    .accessibilityValue(model.pairNext ? "Armed" : "Off")
    .accessibilityIdentifier(identifier)
  }
}
