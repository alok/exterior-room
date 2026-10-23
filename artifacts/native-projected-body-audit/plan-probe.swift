// Diagnostic only: consumes actual executable-Lean input and current native renderer functions.
// This checks CPU data and exports it for a separate offscreen RealityKit experiment.
import Foundation

@main struct PlanProbe {
  static func main() throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else { fatalError("usage: plan-probe lean-d16.json plan-d16.json") }
    let bytes = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
    let input = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
    let cases = input["cases"] as! [[String: Any]]
    func response(_ index: Int) throws -> Data { try JSONSerialization.data(withJSONObject: cases[index]["response"]!) }
    let decoder = JSONDecoder()
    let page = try decoder.decode(PolynomialCataloguePage.self, from: response(0))
    let plane = try decoder.decode(PolynomialPlane.self, from: response(1))
    let members = try decoder.decode(PolynomialCatalogueMembers.self, from: response(2))
    guard page.isValid, plane.isValidPair, page.metadata.total == 4406,
      members.matches(metadata: page.metadata, normal: plane.normal, points: page.points) else {
      fatalError("native decoder rejected audit input")
    }
    let indices = Set(members.indices)
    let points = page.points.enumerated().map { i, p in
      PolynomialPoint(abc: p.abc, xyz: p.xyz, delta: p.delta, kind: p.kind, divisor: p.divisor,
        onPlane: PolynomialSourceMorph.incident(p.abc, normal: plane.normal), necklace: indices.contains(i))
    }
    let rows = page.metadata.coefficientRows.map { Double($0) / Double(page.metadata.denominator) }
    var states: [[String: Any]] = []
    for (name, progress) in [("p0", 0.0), ("p50", 0.5), ("p1", 1.0)] {
      let settings = PolynomialSourceMorph.Settings(depth: 16, progress: progress, hasPlane: true)
      guard let plan = PolynomialRenderPlan.make(points: points, rows: rows, radius: 16, origin: false,
        starSize: 1, colorLower: false, palette: "viridis", normal: nil, keep: [1, 0, 1],
        projection: progress > 0, catalogue: page.metadata, sourceMorph: settings) else {
        fatalError("native renderer plan failed")
      }
      let batches: [[String: Any]] = plan.batches.sorted { $0.key < $1.key }.map { key, indices in
        let color = PolynomialRenderPlan.color(UInt32(key & 0xFFFFFF))
        let raw = plan.materialAlpha[key] ?? 1
        return ["key": String(key), "indices": indices, "rgb": [color.x, color.y, color.z],
          "rawAlpha": raw, "alpha": Double(PolynomialAppearance.linearLightOpacity(raw, color: color))]
      }
      let glyphs: [[String: Any]] = plan.glyphs.map { g in
        ["abc": g.point.abc, "kind": g.point.kind, "divisor": g.point.divisor,
          "position": [Double(g.position.x), Double(g.position.y), Double(g.position.z)],
          "factor": Double(g.factor), "opacity": g.opacity, "physicalRadius": 0.0075 * Double(g.factor)]
      }
      let active = plan.batches.flatMap { key, indices in (plan.materialAlpha[key] ?? 1) > 0 ? indices : [] }
      let visible = plan.glyphs.filter { $0.opacity > 0 }
      let radii = visible.filter { $0.point.kind == 2 && $0.point.divisor == 1 }.map { 0.0075 * Double($0.factor) }.sorted()
      let summary: [String: Any] = ["buffered": plan.glyphs.count,
        "instances": plan.batches.values.reduce(0) { $0 + $1.count }, "positiveBodies": visible.count,
        "positiveMaterialInstances": active.count, "batches": plan.batches.count,
        "primitiveUpperPositiveBodies": radii.count,
        "primitiveUpperRadiusMin": radii.first ?? 0, "primitiveUpperRadiusMedian": radii.isEmpty ? 0 : radii[radii.count/2],
        "primitiveUpperRadiusMax": radii.last ?? 0,
        "samples": glyphs.filter { [[1,0,1],[1,1,1],[1,-1,1],[7,1,8],[2,0,2]].contains($0["abc"] as! [Int]) }]
      states.append(["name": name, "progress": progress, "glyphs": glyphs, "batches": batches, "summary": summary])
      let printed = try JSONSerialization.data(withJSONObject: ["state": name, "summary": summary], options: [.sortedKeys])
      print(String(data: printed, encoding: .utf8)!)
    }
    let sphere = PolynomialRenderPlan.sphere()
    let output: [String: Any] = ["schema": "native-render-probe/v1", "inputBinarySHA256": input["binarySHA256"]!,
      "scope": "Actual native CPU RenderPlan data. Alpha is already converted by linearLightOpacity; do not correct it twice. No GPU/UI assertion.",
      "settings": ["depth": 16, "whole": true, "dust": false, "screen": true, "height": 9.6,
        "starSize": 1, "placement": "overview", "selected": [1,0,1], "second": [1,1,1], "matrix": [1,0,0,1]],
      "mesh": ["positions": sphere.positions.map { [Double($0.x), Double($0.y), Double($0.z)] }, "indices": sphere.indices.map(Int.init)],
      "states": states]
    try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys]).write(to: URL(fileURLWithPath: arguments[2]))
  }
}
