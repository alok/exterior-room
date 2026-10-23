// SPDX-License-Identifier: GPL-3.0-or-later
// Independent Lean-driven route. Placement/control patterns adapted from FareyVision ca809d2975a37a318a425e4b9dd73560b07faf39.
// Alok Singh with OpenAI Codex, 2026-10-23.
import SwiftUI

@main struct PolynomialRoomApp: App {
  @State private var model = PolynomialModel()
  var body: some Scene {
    Window("Lean Starscape", id: "polynomial-launch") { PolynomialControls().environment(model) }
      .defaultSize(width: 660,height: 900)
      .defaultWindowPlacement { _, _ in WindowPlacement(.utilityPanel) }
    Window("Roots · Lean Starscape",id:"polynomial-roots") { PolynomialRootsView().environment(model) }
      .defaultSize(width:560,height:760)
      .defaultWindowPlacement { _, context in
        if let launch = context.windows.first(where: { $0.id == "polynomial-launch" }) { return WindowPlacement(.trailing(launch)) }
        return WindowPlacement()
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
        Button(lower ? "Face upper nappe" : "Face lower nappe") { model.placement = .origin(lower:!lower) }
          .accessibilityIdentifier("poly-flip-nappe")
      }
      Text(placementText).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("poly-placement")
      HStack {
        Button("Roots…") { openWindow(id:"polynomial-roots") }.accessibilityIdentifier("poly-roots-open")
        Button(transforms ? "Point controls" : "SL₂ transform") { transforms.toggle() }
          .accessibilityIdentifier("poly-action-mode")
        if !transforms, model.action != nil {
          Text(model.actionStatus).font(.caption2).foregroundStyle(.mint)
        }
      }
      if transforms { PolynomialTransformControls().environment(model) }
      if !collapsed && !transforms {
        Divider()
        HStack {
          TextField("a, b, c",text:$entry).textFieldStyle(.roundedBorder).accessibilityIdentifier("poly-entry")
          Button("Select") { if let p = parse(entry) { model.enter(p) } }.disabled(model.busy).accessibilityIdentifier("poly-select")
        }
        HStack {
          Button("Next") { model.nextCoefficient() }.disabled(model.busy).accessibilityIdentifier("poly-next")
          Button("Upper") { choose([1,0,1]) }.accessibilityIdentifier("poly-upper")
          Button("Lower") { choose([-1,0,-1]) }.accessibilityIdentifier("poly-lower")
          Button("Exterior") { choose([1,0,-1]) }.accessibilityIdentifier("poly-exterior")
          Spacer()
          Button("R\(model.radius)") {
            let values = [4,6,8,10,12], index = values.firstIndex(of:model.radius) ?? 1
            model.radius = values[(index+1)%values.count]; model.refresh()
          }.disabled(model.busy).accessibilityIdentifier("poly-radius")
          Toggle("Dense · R12",isOn:Binding(get:{ model.radius == 12 },set:{ model.radius = $0 ? 12 : 6; model.refresh() }))
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
          Toggle("Projection",isOn:$model.showProjection).toggleStyle(.button).accessibilityIdentifier("poly-projection")
          Button(["Oblique","Other side","Side view"][model.viewpoint]) { model.viewpoint = (model.viewpoint+1)%3 }
            .disabled(model.placement != .overview).accessibilityIdentifier("poly-view")
          Spacer()
          Text("\(String(model.points.count)) signed triples · R\(model.displayedRadius)")
            .font(.caption).accessibilityIdentifier("poly-count")
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
        Text("\(model.points.filter(\.necklace).count) displayed interior triples on the plane")
          .font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("poly-members")
      }
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
    case .origin: "Origin placed once at head center · select with controls"
    case .inhabit: "Inhabit · point placed 35 cm ahead · select with controls"
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
