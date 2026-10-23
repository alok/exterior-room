// SPDX-License-Identifier: GPL-3.0-or-later
// Lifecycle adapted from FareyVision 8b32d7a. See native/README.md.
import SwiftUI

@main struct ExteriorRoomApp: App {
  @State private var model = LeanModel()
  var body: some Scene {
    Window("Exterior Room", id: "launch") {
      ControlView().environment(model)
    }
    .defaultSize(width: 700, height: 730)
    .defaultWindowPlacement { _, _ in WindowPlacement(.utilityPanel) }
    ImmersiveSpace(id: "exterior-room") {
      ExteriorSpace().environment(model)
    }
    .immersionStyle(selection: .constant(.full), in: .full)
  }
}

enum VectorPalette {
  static let names = ["a", "b", "c"]
  static let colors = [Color(red: 1, green: 145.0/255, blue: 117.0/255),
    Color(red: 103.0/255, green: 228.0/255, blue: 200.0/255),
    Color(red: 184.0/255, green: 160.0/255, blue: 1)]
}

struct ControlView: View {
  @Environment(LeanModel.self) private var model
  @Environment(\.openImmersiveSpace) private var openSpace
  @Environment(\.dismissImmersiveSpace) private var dismissSpace
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    @Bindable var model = model
    VStack(alignment: .leading, spacing: 15) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("EXTERIOR ROOM").font(.caption.weight(.bold)).tracking(5).foregroundStyle(.mint)
          Text("Give algebra some room.").font(.system(size: 32, weight: .light, design: .serif))
        }
        Spacer()
        Button(model.spaceOpen ? "Leave space" : "Enter space") { toggleSpace() }
          .buttonStyle(.borderedProminent).tint(.mint)
          .disabled(model.transitioning || model.result == nil).accessibilityIdentifier("toggle-space")
      }
      Text(model.status).font(.callout).foregroundStyle(model.live ? Color.mint : Color.secondary)
        .accessibilityIdentifier("lean-status")
      if let result = model.result {
        HStack(spacing: 24) {
          VStack(alignment: .leading, spacing: 4) {
            Text("a ∧ b").font(.title2).foregroundStyle(.mint)
            Text(result.wedgeText)
              .font(.system(.title3, design: .monospaced)).accessibilityIdentifier("wedge-value")
            Text("e₁₂ · e₁₃ · e₂₃").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 4) {
            Text("Oriented volume").foregroundStyle(.secondary)
            Text(result.volumeText).font(.system(.title, design: .monospaced))
              .accessibilityIdentifier("volume-value")
          }
        }
      }
      HStack {
        ForEach(Array(model.presets.indices), id: \.self) { index in
          Button(LeanModel.presetNames[index]) { model.showPreset(index) }
            .tint(model.presetIndex == index ? .mint : .gray)
            .accessibilityIdentifier("preset-\(index)")
        }
        Spacer()
        Button("Reset") { model.reset() }.accessibilityIdentifier("reset")
      }
      Divider()
      HStack {
        Text("Move").foregroundStyle(.secondary)
        ForEach(0..<3, id: \.self) { index in
          Button(VectorPalette.names[index]) { model.selectedVector = index }
            .font(.headline).tint(VectorPalette.colors[index])
            .buttonStyle(.borderedProminent)
            .opacity(model.selectedVector == index ? 1 : 0.5)
            .accessibilityIdentifier("vector-\(index)")
        }
        Spacer()
        Text("¼-unit grid").font(.caption).foregroundStyle(.secondary)
      }
      HStack(spacing: 15) {
        ForEach(0..<3, id: \.self) { axis in
          let name = ["x", "y", "z"][axis]
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
              Text(name).font(.caption).foregroundStyle(.secondary)
              Text(String(format: "%.2f", Double(model.vectors[model.selectedVector][axis]) / 4))
                .font(.system(.body, design: .monospaced)).monospacedDigit()
                .accessibilityIdentifier("coordinate-\(name)")
            }
            Button("−") { model.setCoordinate(axis, quarter: model.vectors[model.selectedVector][axis] - 1) }
              .disabled(model.vectors[model.selectedVector][axis] <= -12)
              .accessibilityLabel("Decrease \(name)").accessibilityIdentifier("\(name)-minus")
            Button("+") { model.setCoordinate(axis, quarter: model.vectors[model.selectedVector][axis] + 1) }
              .disabled(model.vectors[model.selectedVector][axis] >= 12)
              .accessibilityLabel("Increase \(name)").accessibilityIdentifier("\(name)-plus")
          }
          .buttonStyle(.borderless)
          .padding(10).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
        }
      }.disabled(model.result == nil)
      HStack {
        Button("Swap a ↔ b") { model.swap() }.accessibilityIdentifier("swap")
        Button("Flatten c = b") { model.flatten() }.accessibilityIdentifier("flatten")
        Spacer()
        Toggle("Volume", isOn: $model.showVolume).toggleStyle(.button).accessibilityIdentifier("volume-toggle")
      }
      HStack {
        Button("Overview") { model.inside = false }.tint(model.inside ? .gray : .mint)
          .accessibilityIdentifier("overview")
        Button("Inside") { model.inside = true }.tint(model.inside ? .mint : .gray)
          .accessibilityIdentifier("inside")
        Spacer()
        Text(model.live ? "Drag an endpoint · release to compute" : "Presets work offline · edits need the Mac bridge")
          .font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      HStack {
        TextField("Mac bridge URL", text: $model.server)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .textFieldStyle(.roundedBorder).accessibilityIdentifier("bridge-url")
        Button(model.busy ? "Computing…" : "Connect") { model.connect() }
          .disabled(model.busy || model.result == nil).accessibilityIdentifier("connect")
      }
      Text("Exact: Lean on the Mac. Rendering: RealityKit. Kernel proofs: build time.")
        .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("proof-boundary")
      if let error = model.error { Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("lean-error") }
      Spacer(minLength: 0)
    }.padding(26)
  }

  private func toggleSpace() {
    model.transitioning = true
    Task { @MainActor in
      defer { model.transitioning = false }
      if model.spaceOpen {
        openWindow(id: "launch")
        await Task.yield()
        await dismissSpace()
      }
      else {
        switch await openSpace(id: "exterior-room") {
        case .opened:
          model.spaceOpen = true
          dismissWindow(id: "launch")
        case .userCancelled: model.error = "Space entry cancelled."
        case .error: model.error = "The immersive space could not open."
        @unknown default: model.error = "Unknown immersive-space result."
        }
      }
    }
  }
}
