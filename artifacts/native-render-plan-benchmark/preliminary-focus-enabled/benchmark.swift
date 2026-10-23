// Diagnostic only: current native CPU functions and native-validated executable-Lean input.
// No RealityKit, UI, GPU work or catalogue computation is included in the timed region.
import Foundation
import Dispatch

@main struct RenderPlanBenchmark {
  static func json(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  }
  static func summary(_ plan: PolynomialRenderPlan.Snapshot) -> [String: Any] {
    var checksum = 0.0
    for (index, glyph) in plan.glyphs.enumerated() {
      checksum += Double(index + 1) * (Double(glyph.position.x) + 2 * Double(glyph.position.y)
        + 3 * Double(glyph.position.z) + Double(glyph.factor) + glyph.opacity)
    }
    return ["buffered": plan.glyphs.count, "batches": plan.batches.count,
      "instances": plan.batches.values.reduce(0) { $0 + $1.count },
      "positiveBodies": plan.glyphs.filter { $0.opacity > 0 }.count,
      "positiveMaterialInstances": plan.batches.reduce(0) { $0 + ((plan.materialAlpha[$1.key] ?? 1) > 0 ? $1.value.count : 0) },
      "primitiveUpperPositiveBodies": plan.glyphs.filter { $0.opacity > 0 && $0.point.kind == 2 && $0.point.divisor == 1 }.count,
      "radialPositions": plan.radialPositions.count, "consumedGlyphChecksum": checksum]
  }
  static func main() throws {
    guard CommandLine.arguments.count == 3 else { fatalError("usage: render-plan-benchmark input.json results.json") }
    let input = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
    let decoder = JSONDecoder()
    let pair = input["pair"] as! [String: Any]
    let plane = try decoder.decode(PolynomialPlane.self, from: json(pair["response"]!))
    guard plane.isValidPair, plane.normal == [1, 0, -1] else { fatalError("native pair validation failed") }
    var results: [[String: Any]] = []
    for dataset in input["datasets"] as! [[String: Any]] {
      let name = dataset["name"] as! String, depth = dataset["depth"] as! Int
      let matrix = dataset["matrix"] as! [Int]
      let rawPages = dataset["pages"] as! [[String: Any]]
      let pages = try rawPages.map { try decoder.decode(PolynomialCataloguePage.self, from: json($0["response"]!)) }
      guard let first = pages.first else { fatalError("missing page") }
      let metadata = first.metadata
      var points: [PolynomialPoint] = [], offset = 0
      for page in pages {
        guard page.matches(depth: depth, matrix: matrix, whole: true, dust: false, offset: offset),
          metadata.sameCatalogue(as: page.metadata) else { fatalError("native catalogue validation failed") }
        let next = page.points
        if let previous = points.last, let current = next.first, offset != metadata.upperCount {
          guard previous.abc.lexicographicallyPrecedes(current.abc) else { fatalError("cross-page order invalid") }
        }
        points.append(contentsOf: next)
        offset += page.count
      }
      guard points.count == metadata.total, pages.last!.nextOffset == nil else { fatalError("incomplete pagination") }
      let rawMembers = dataset["members"] as! [String: Any]
      let members = try decoder.decode(PolynomialCatalogueMembers.self, from: json(rawMembers["response"]!))
      guard members.matches(metadata: metadata, normal: plane.normal, points: points) else { fatalError("native membership validation failed") }
      let necklace = Set(members.indices)
      points = points.enumerated().map { index, point in
        PolynomialPoint(abc: point.abc, xyz: point.xyz, delta: point.delta, kind: point.kind,
          divisor: point.divisor, onPlane: PolynomialSourceMorph.incident(point.abc, normal: plane.normal),
          necklace: necklace.contains(index))
      }
      let rows = metadata.coefficientRows.map { Double($0) / Double(metadata.denominator) }
      let cartesian = plane.cartesianNormal
      guard let focusNormal = PolynomialMobius.mapPlaneNormal(rows: rows,
        [Double(cartesian[0]), Double(cartesian[1]), Double(cartesian[2])]) else { fatalError("invalid mapped plane normal") }
      var rawMetadata = rawPages[0]["response"] as! [String: Any]
      for key in ["abc", "xyz", "delta", "kind", "divisor", "primitive", "onPlane", "necklace", "offset", "count", "nextOffset"] {
        rawMetadata.removeValue(forKey: key)
      }
      for progress in [0.0, 0.5, 1.0] {
        let settings = PolynomialSourceMorph.Settings(depth: depth, heightFraction: 0.6,
          progress: progress, eye: 0, sigma: 1, whole: true, dust: false, screen: true, light: false, hasPlane: true)
        var durations: [Double] = [], warmup = 0.0, firstSummary: Data?, counts: [String: Any] = [:]
        // One warmup and three measurements; all summaries/validation occur after the stop timestamp.
        for repetition in 0..<4 {
          let start = DispatchTime.now().uptimeNanoseconds
          let result = PolynomialRenderPlan.make(points: points, rows: rows, radius: depth, origin: false,
            starSize: 1, colorLower: false, palette: "viridis", normal: focusNormal, keep: [1, 0, 1],
            projection: true, catalogue: metadata, sourceMorph: settings)
          let stop = DispatchTime.now().uptimeNanoseconds
          guard let plan = result else { fatalError("render plan rejected accepted input") }
          let milliseconds = Double(stop - start) / 1_000_000
          counts = summary(plan)
          let summaryBytes = try json(counts)
          if let firstSummary { guard firstSummary == summaryBytes else { fatalError("non-deterministic counts/checksum") } }
          else { firstSummary = summaryBytes }
          if repetition == 0 { warmup = milliseconds } else { durations.append(milliseconds) }
        }
        let row: [String: Any] = ["dataset": name, "depth": depth, "matrix": matrix, "progress": progress,
          "metadata": rawMetadata, "nativeDecoderValidated": true, "pageCount": pages.count,
          "planeMembers": members.count, "whole": true, "dust": false, "overview": true,
          "starSize": 1, "screen": true, "heightFraction": 0.6, "planeNormal": plane.normal,
          "projection": true, "planeFocus": true,
          "mappedFocusNormal": [focusNormal.x, focusNormal.y, focusNormal.z],
          "warmupMillisecondsExcluded": warmup, "measuredMilliseconds": durations,
          "meanMilliseconds": durations.reduce(0,+) / Double(durations.count),
          "minMilliseconds": durations.min()!, "maxMilliseconds": durations.max()!, "counts": counts]
        results.append(row)
        print(String(data: try json(row), encoding: .utf8)!)
      }
    }
    let output: [String: Any] = ["schema": "native-render-plan-benchmark-results-v1",
      "scope": "Standalone macOS CPU PolynomialRenderPlan.make only; -Onone; one process, serial calls. No service/decode/summary/GPU/UI timing.",
      "warmupsPerConfiguration": 1, "measurementsPerConfiguration": 3,
      "configurationCount": results.count, "clock": "DispatchTime uptimeNanoseconds",
      "peakRSS": NSNull(), "peakRSSNote": "Not collected; no claim about peak renderer/app memory.",
      "configurations": results]
    try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
      .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
  }
}
