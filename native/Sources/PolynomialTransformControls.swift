// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Explicit approximate preview / accepted Lean action boundary.
import SwiftUI

struct PolynomialTransformControls: View {
  @Environment(PolynomialModel.self) private var model
  @GestureState private var gestureActive = false
  @State private var attempted = false
  @State private var dragState = "No drag sample yet"
  @State private var recognizedGestures = 0
  @State private var changedCallbacks = 0
  @State private var endedCallbacks = 0
  @State private var cancelledGestures = 0
  @State private var rejectedBy = "none"
  @State private var diagnosticStart = CGPoint.zero
  @State private var diagnosticLocation = CGPoint.zero
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["POLYNOMIAL_GESTURE_DIAGNOSTICS"] == "1"

  var body: some View {
    @Bindable var model = model
    VStack(alignment:.leading,spacing:6) {
      HStack {
        Button("T") { model.applyGenerator([1,1,0,1]) }.accessibilityIdentifier("poly-action-t")
        Button("T⁻¹") { model.applyGenerator([1,-1,0,1]) }.accessibilityIdentifier("poly-action-t-inverse")
        Button("S") { model.applyGenerator([0,-1,1,0]) }.accessibilityIdentifier("poly-action-s")
        Button("i → 1+i") { model.requestAction([3,1,1,2]) }.accessibilityIdentifier("poly-action-checkpoint")
        Spacer()
        Button("Identity") { model.requestAction([1,0,0,1]) }.accessibilityIdentifier("poly-action-identity")
      }.disabled(model.busy || model.actionPreview != nil)
      HStack {
        Button("Snap") { model.snapAction() }.accessibilityIdentifier("poly-action-snap")
        Toggle("Snap on release",isOn:Binding(get:{model.snapOnRelease},set:{model.setSnapOnRelease($0)})).toggleStyle(.button)
          .accessibilityIdentifier("poly-action-snap-release")
        if diagnosticsEnabled {
          Button("Vertical ×10") { model.requestAction([50,18,0,5]) }
            .help("Source transvection from −0.4 + 0.1i to −0.4 + i, declared exactly as M = [50,18,0,5].")
            .accessibilityIdentifier("poly-action-vertical")
        }
        Spacer()
        Button("Source (13,20,34)") { model.select([13,20,34]) }
          .accessibilityIdentifier("poly-action-source")
      }.disabled(model.busy || model.actionPreview != nil)
      Text(model.actionStatus).font(.caption).foregroundStyle(model.actionPreview == nil ? Color.mint : Color.orange)
        .accessibilityIdentifier("poly-action-status")
      if let action = model.action {
        Text("M = [\(action.matrix.map(String.init).joined(separator:", "))] · D = \(action.denominator)")
          .font(.caption.monospaced()).accessibilityIdentifier("poly-action-matrix")
        Text("Image: (\(action.imageNumerator.map { fraction($0,action.denominator) }.joined(separator:", ")))")
          .font(.body.monospaced()).accessibilityIdentifier("poly-action-image")
      }
      GeometryReader { geometry in
        Canvas { context, size in
          let diameter = min(size.width,size.height)-16
          let center = CGPoint(x:size.width/2,y:size.height/2)
          let circle = CGRect(x:center.x-diameter/2,y:center.y-diameter/2,width:diameter,height:diameter)
          context.fill(Path(ellipseIn:circle),with:.color(.black.opacity(0.55)))
          context.stroke(Path(ellipseIn:circle),with:.color(.mint.opacity(0.7)),lineWidth:2)
          let rows = model.displayActionRows
          for point in model.points where point.kind == 2 {
            guard let image = PolynomialMobius.mapDisplay(rows:rows,point.vector), image.y > 0 else { continue }
            let u = Double(image.x/image.y), v = Double(image.z/image.y)
            guard u*u+v*v < 1 else { continue }
            let selected = point.abc == model.inspection?.point
            let radius: CGFloat = selected ? 3.5 : 1.4
            let location = CGPoint(x:center.x+u*diameter/2,y:center.y-v*diameter/2)
            context.fill(Path(ellipseIn:CGRect(x:location.x-radius,y:location.y-radius,width:2*radius,height:2*radius)),
              with:.color(selected ? .white : .mint.opacity(0.65)))
          }
        }
        .contentShape(Rectangle()).accessibilityElement(children:.ignore)
        .accessibilityLabel("Klein transformation disk").accessibilityIdentifier("poly-action-disk")
        .highPriorityGesture(DragGesture(minimumDistance:4)
          .updating($gestureActive) { _, state, _ in state = true }
          .onChanged { value in
            // Record rejected callbacks as well as accepted ones, so a diagnostic can distinguish
            // missing input from input received while the controls are unavailable.
            changedCallbacks += 1
            if diagnosticsEnabled { diagnosticStart = value.startLocation; diagnosticLocation = value.location }
            rejectedBy = !model.placement.isOrigin ? "placement" : (model.busy ? "busy" : "none")
            guard model.placement.isOrigin else { dragState = "Drag received · choose Origin"; return }
            guard !model.busy else { dragState = "Drag received · waiting for Lean"; return }
            if !attempted {
              attempted = true
              model.beginActionDrag(at:klein(value.startLocation,size:geometry.size))
            }
            model.updateActionDrag(to:klein(value.location,size:geometry.size))
            dragState = model.actionPreview == nil ? "Drag outside disk · unchanged" : "Drag preview active"
          }
          .onEnded { value in
            endedCallbacks += 1
            if diagnosticsEnabled { diagnosticLocation = value.location }
            model.updateActionDrag(to:klein(value.location,size:geometry.size),force:true)
            dragState = model.actionPreview == nil ? "Drag ended without sample" : "Released sample to Lean"
            attempted = false; model.commitActionDrag()
          })
        .allowsHitTesting(model.placement.isOrigin && !model.busy)
      // Match the interaction and accessibility bounds to the visible disk. A wide, shallow
      // Canvas advertised empty side margins as draggable even though they are outside Klein space.
      }.frame(width:170,height:170).frame(maxWidth:.infinity)
      HStack {
        Text("Move").font(.caption)
        Button("←") { model.nudgeAction([-0.2,0]) }.accessibilityIdentifier("poly-action-left")
        Button("→") { model.nudgeAction([0.2,0]) }.accessibilityIdentifier("poly-action-right")
        Button("↑") { model.nudgeAction([0,0.2]) }.accessibilityIdentifier("poly-action-up")
        Button("↓") { model.nudgeAction([0,-0.2]) }.accessibilityIdentifier("poly-action-down")
      }.disabled(!model.placement.isOrigin || model.busy)
      Text(model.placement.isOrigin ? dragState : "Choose Origin to drag in the Klein disk.")
        .accessibilityIdentifier("poly-action-drag-state")
        .font(.caption).foregroundStyle(.secondary)
      if diagnosticsEnabled {
        Text("Recognized \(recognizedGestures) · changed \(changedCallbacks) · ended \(endedCallbacks) · cancelled \(cancelledGestures) · guard \(rejectedBy)")
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-action-diagnostics")
        Text(String(format:"Local start (%.1f, %.1f) · current (%.1f, %.1f)",
          diagnosticStart.x,diagnosticStart.y,diagnosticLocation.x,diagnosticLocation.y))
          .font(.caption2.monospaced()).accessibilityIdentifier("poly-action-diagnostic-coordinates")
      }
      Text("Preview and Snap choice use floating point; Lean accepts the exact declared sample. Snap / integer generators relabel both selections atomically. Identity keeps those labels. The R12 maximum base crop stays fixed under continuous action.")
        .font(.caption2).foregroundStyle(.secondary)
    }
    .onChange(of:gestureActive) { _, active in
      if active { recognizedGestures += 1 }
      if !active {
        // GestureState can reset before onEnded. Let the end callback submit its sample first;
        // an interrupted gesture still disposes its preview on the next main-actor turn.
        Task { @MainActor in
          await Task.yield()
          if !gestureActive && attempted {
            cancelledGestures += 1
            attempted = false; model.cancelActionDrag(); dragState = "Drag cancelled · accepted scene retained"
          }
        }
      }
    }
    .onDisappear { attempted = false; model.cancelActionDrag() }
  }
  private func klein(_ point: CGPoint,size:CGSize) -> SIMD2<Double> {
    let radius = max(1,(min(size.width,size.height)-16)/2)
    return SIMD2(Double((point.x-size.width/2)/radius),Double((size.height/2-point.y)/radius))
  }
  private func fraction(_ numerator:Int,_ denominator:Int) -> String {
    var a = abs(numerator), b = denominator
    while b != 0 { (a,b) = (b,a%b) }
    let divisor = max(1,a), n = numerator/divisor, d = denominator/divisor
    return d == 1 ? String(n) : "\(n)/\(d)"
  }
}
