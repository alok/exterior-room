// SPDX-License-Identifier: GPL-3.0-or-later
// Uses the exact decoder compiled into the native app, not a parallel model.
import Foundation

@main struct VerifyExports {
  @MainActor static func main() async throws {
    let file = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/presets.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: file))
    let exports = try JSONDecoder().decode([LeanResult].self, from: data)
    precondition(!exports.isEmpty, "No Lean exports found")
    precondition(exports.allSatisfy(\.isValid), "A Lean export failed native schema bounds")
    print("PASS: native app decoder accepted \(exports.count) Lean-generated presets")
    if CommandLine.arguments.count > 2 {
      let base = URL(string: CommandLine.arguments[2])!
      for (index, fixture) in exports.enumerated() {
        var request = URLRequest(url: base.appendingPathComponent("api/evaluate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
          "id": index + 9000, "a": fixture.a, "b": fixture.b, "c": fixture.c,
        ])
        let (body, response) = try await URLSession.shared.data(for: request)
        precondition((response as? HTTPURLResponse)?.statusCode == 200)
        let actual = try JSONDecoder().decode(LeanResult.self, from: body)
        precondition(actual.isValid && actual.id == index + 9000)
        precondition(actual.vectors == fixture.vectors)
        precondition(actual.wedge == fixture.wedge && actual.swappedWedge == fixture.swappedWedge)
        precondition(actual.selfWedge == fixture.selfWedge && actual.volume == fixture.volume)
        precondition(actual.vertices == fixture.vertices)
      }
      print("PASS: URLSession live bridge round trips match all Lean exports")
      let model = LeanModel(presetData: data)
      model.server = base.absoluteString
      model.showPreset(1)
      model.connect()
      await model.waitForPending()
      precondition(model.live && model.result?.volume == 64)
      model.swap()
      await model.waitForPending()
      precondition(model.live && model.result?.volume == -64)
      model.flatten()
      await model.waitForPending()
      precondition(model.live && model.result?.volume == 0)
      model.reset()
      await model.waitForPending()
      precondition(model.live && model.result?.volume == 294)
      model.selectedVector = 2
      model.setCoordinate(0, quarter: 2)
      await model.waitForPending()
      precondition(model.live && model.result?.c == [2,1,7])
      print("PASS: actual native model → Lean unit/swap/flatten/reset/coordinate sequence")
    }
  }
}
