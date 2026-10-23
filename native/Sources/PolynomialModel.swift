// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Exact data comes from polynomial_service.
import Foundation
import Observation

struct PolynomialHeader: Decodable {
  let ok: Bool
  let id: Int
  let schema: String
  let engine: String
  let sourceCommit: String
  let error: String?
  var recognized: Bool {
    schema == "polynomial-space-v1" && engine == "Lean 4.35.0-rc3"
      && sourceCommit == "ca809d2975a37a318a425e4b9dd73560b07faf39"
  }
}

struct PolynomialCloud: Decodable {
  let radius: Int, offset: Int, count: Int, total: Int
  let upperOnly: Bool
  let nextOffset: Int?
  let abc: [Int], xyz: [Int], delta: [Int], kind: [Int], divisor: [Int]
  var isValid: Bool {
    guard (4...96).contains(radius), count >= 0, count <= 16384, (0...2_000_000).contains(offset),
      total >= offset + count, total <= 2_000_000,
      abc.count == count * 3, xyz.count == count * 3,
      [delta.count, kind.count, divisor.count].allSatisfy({ $0 == count }),
      abc.allSatisfy({ (-96...96).contains($0) }), xyz.allSatisfy({ (-192...192).contains($0) }),
      delta.allSatisfy({ (-46_080...46_080).contains($0) }),
      kind.allSatisfy({ (0...3).contains($0) }), divisor.allSatisfy({ (1...96).contains($0) }),
      nextOffset == (offset + count < total ? offset + count : nil)
    else { return false }
    for i in 0..<count {
      let j = i * 3, a = abc[j], b = abc[j+1], c = abc[j+2]
      guard a != 0 || b != 0 || c != 0,
        Array(xyz[j..<(j+3)]) == [-b, a+c, c-a],
        (kind[i] == 0 ? delta[i] == 0 : kind[i] == 1 ? delta[i] > 0 : delta[i] < 0),
        kind[i] != 2 || a > 0, kind[i] != 3 || a < 0,
        delta[i] >= 0 || xyz[j+1] != 0
      else { return false }
    }
    return true
  }
  var points: [PolynomialPoint] {
    (0..<count).map { i in
      let j = i * 3
      return PolynomialPoint(abc: Array(abc[j..<(j+3)]), xyz: Array(xyz[j..<(j+3)]),
        delta: delta[i], kind: kind[i], divisor: divisor[i], onPlane: false, necklace: false)
    }
  }
}

struct PolynomialInspection: Decodable {
  struct Root: Decodable {
    struct Imaginary: Decodable { let radicand: Int, denominator: Int }
    let real: [Int]
    let imaginary: Imaginary
  }
  let point: [Int], xyz: [Int], primitive: [Int]
  let polynomial: String, kind: String
  let delta: Int, divisor: Int
  let positiveRepresentative: [Int]?
  let projection: [[Int]]?
  let root: Root?
  var displayPolynomial: String { PolynomialLabels.spaced(polynomial) }
  var isValid: Bool {
    let bound = PolynomialIdentityBounds.coordinate
    guard point.count == 3, point.allSatisfy({ (-bound...bound).contains($0) }), point != [0,0,0],
      xyz == [-point[1], point[0]+point[2], point[2]-point[0]],
      primitive.count == 3, primitive.allSatisfy({ (-bound...bound).contains($0) }),
      (1...bound).contains(divisor), (-PolynomialIdentityBounds.delta...PolynomialIdentityBounds.delta).contains(delta),
      ["null", "exterior", "upper", "lower"].contains(kind), !polynomial.isEmpty,
      (kind == "null" ? delta == 0 : kind == "exterior" ? delta > 0 : delta < 0),
      kind != "upper" || point[0] > 0, kind != "lower" || point[0] < 0
    else { return false }
    let sign = (point.first(where: { $0 != 0 }) ?? 1) < 0 ? -1 : 1
    guard point.allSatisfy({ $0 % divisor == 0 }), primitive == point.map({ $0 / divisor * sign }) else { return false }
    if delta < 0 {
      guard positiveRepresentative == point.map({ $0 * (point[0] < 0 ? -1 : 1) }), projection != nil, root != nil else { return false }
    } else if positiveRepresentative != nil || root != nil { return false }
    if let projection, !(projection.count == 3 && projection.allSatisfy({
      $0.count == 2 && (-48*bound...48*bound).contains($0[0]) && (1...2*bound).contains($0[1])
    })) { return false }
    if let root, !(root.real.count == 2 && (-bound...bound).contains(root.real[0]) && (1...2*bound).contains(root.real[1])
      && (1...4*bound*bound).contains(root.imaginary.radicand) && (1...2*bound).contains(root.imaginary.denominator)) { return false }
    return true
  }
  var rootText: String {
    guard let root else { return kind == "exterior" ? "Two real projective roots" : "Boundary of the cone" }
    return "\(root.real[0])/\(root.real[1]) + i√\(root.imaginary.radicand)/\(root.imaginary.denominator)"
  }
}

/// Typography only: keep the exact signed Lean label untouched in transport and model data.
enum PolynomialLabels {
  static func spaced(_ raw: String) -> String {
    let characters = raw.filter { !$0.isWhitespace }
    return characters.enumerated().map { index, character in
      index > 0 && (character == "+" || character == "−" || character == "-")
        ? " \(character) " : String(character)
    }.joined()
  }
}

struct PolynomialPlane: Decodable {
  struct Endpoint: Decodable {
    let kind: String, label: String
    let numerator: Int?, denominator: Int?
    let p: Int?, sign: Int?, s: Int?, r: Int?, q: Int?
    var isValid: Bool {
      switch kind {
      case "infinity": return true
      case "rational": return numerator != nil && (denominator ?? 0) > 0
      case "surd": return p != nil && [1,-1].contains(sign ?? 0) && (s ?? 0) > 0 && (r ?? 0) > 1 && (q ?? 0) > 0
      default: return false
      }
    }
    /// Approximate display conversion only; the label remains the exact Lean descriptor.
    var displayValue: Double {
      switch kind {
      case "infinity": return .infinity
      case "rational": return Double(numerator!) / Double(denominator!)
      default: return (Double(p!) + Double(sign!) * Double(s!) * sqrt(Double(r!))) / Double(q!)
      }
    }
  }
  let normal: [Int], planeCoefficients: [Int], cartesianNormal: [Int]
  let equation: String, endpoints: [Endpoint], checks: [String: Bool]
  var isValid: Bool {
    guard normal.count == 3, normal.allSatisfy({ (-PolynomialIdentityBounds.normal...PolynomialIdentityBounds.normal).contains($0) }),
      normal != [0,0,0], endpoints.count == 2, endpoints.allSatisfy(\.isValid),
      checks["exterior"] == true, checks["primitive"] == true,
      checks.values.allSatisfy({ $0 }), !equation.isEmpty
    else { return false }
    return planeCoefficients == [-2*normal[2], normal[1], -2*normal[0]]
      && cartesianNormal == [-normal[1], -normal[0]-normal[2], normal[2]-normal[0]]
  }
  var isValidPair: Bool {
    isValid && ["firstOnPlane","secondOnPlane","rawFirstOnPlane","rawSecondOnPlane"].allSatisfy { checks[$0] == true }
  }
}

private struct PolynomialMembers: Decodable {
  let radius: Int, total: Int, count: Int
  let upperOnly: Bool, indices: [Int]
}

enum PolynomialCatalogueMode: String, CaseIterable {
  case ball = "Canonical ball", source = "Source depth"
}

enum PolynomialPlacement: Equatable {
  case overview, origin(lower: Bool), inhabit(xyz: [Int])
  var isOrigin: Bool { if case .origin = self { true } else { false } }
}

@MainActor @Observable final class PolynomialModel {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
  static let nextSequence = [[1,-1,2],[2,-2,4],[2,1,1],[1,0,1],[3,2,2],[-1,1,-2],[1,2,1],[1,3,1]]
  var server = "http://127.0.0.1:8787"
  var radius = 6
  var catalogueMode = PolynomialCatalogueMode.ball
  var whole = true
  var dust = false
  private(set) var catalogue: PolynomialCatalogueMetadata?
  private var acceptedMode = PolynomialCatalogueMode.ball
  private var acceptedUpperOnly = false
  private var acceptedWhole = true
  private var acceptedDust = false
  private var cachedCatalogue: PolynomialCatalogueMetadata?
  private(set) var displayedRadius = 6
  var upperOnly = false
  var colorLower = false
  var palette = "viridis"
  var starSize = 1.0
  var planeFocus = false
  var showCone = true
  var showProjection = false
  private(set) var projectionProgress = 0.0
  var projectionHeightFraction = 0.6
  var showSourceScreen = true
  private(set) var projectionAnimating = false
  private var projectionTask:Task<Void,Never>?
  private(set) var previewPoints:[PolynomialPoint]?
  private(set) var previewCatalogue:PolynomialCatalogueMetadata?
  private(set) var previewCatalogueRevision = 0
  private(set) var previewCatalogueAcceptances = 0
  private(set) var previewCatalogueStatus = ""
  private var previewCatalogueGeneration = 0
  private var previewCatalogueTask:Task<Void,Never>?
  private var pendingPreviewMatrix:[Int]?
  private var lastCatalogueStart = 0.0
  var renderPoints:[PolynomialPoint] { previewPoints ?? points }
  var renderCatalogue:PolynomialCatalogueMetadata? { previewCatalogue ?? catalogue }
  var sourceMorphSettings:PolynomialSourceMorph.Settings? {
    guard let catalogue=renderCatalogue else { return nil }
    return .init(depth:catalogue.depth,heightFraction:projectionHeightFraction,progress:projectionProgress,
      eye:placement.isOrigin ? 1:0,sigma:starSize,whole:catalogue.whole,dust:catalogue.dust,screen:showSourceScreen,hasPlane:plane != nil)
  }
  var viewpoint = 0
  var placement = PolynomialPlacement.overview
  var placementEpoch = 0
  var rendererStats = "Renderer waiting"
  var spaceOpen = false
  var rootsOpen = false
  var transitioning = false
  var points: [PolynomialPoint] = []
  var inspection: PolynomialInspection?
  private(set) var pairedInspection: PolynomialInspection?
  var plane: PolynomialPlane?
  var selected = [1,-1,2]
  var paired: [Int]?
  private(set) var displayedPair: [Int]?
  private(set) var pairNext = false
  private var armedPairRequest = false
  var busy = false
  var status = "Lean export · signed quadratic coefficients"
  var error: String?
  var sceneRevision = 0
  var actionMatrix = [1,0,0,1]
  var snapOnRelease = false
  private(set) var action: PolynomialAction?
  private(set) var actionPreview: PolynomialActionPreview?
  private(set) var actionRevision = 0
  private enum DragSurface { case klein, roots, spatial }
  private var dragSurface: DragSurface?
  private var spatialEpoch = -1
  private var spatialPlacement:PolynomialPlacement?
  private var spatialNeedsAnchor = true
  private var spatialMoved = false
  var spatialTargetReady = false
  private(set) var spatialInputCallbacks = 0
  private(set) var spatialInputReleases = 0
  private(set) var spatialInputStatus = "No spatial drag sample"
  var ownsSpatialDrag:Bool { dragSurface == .spatial }
  var rootsResetRevision = 0
  private(set) var hoveredPoint: [Int]?
  private(set) var hoverInspection: PolynomialInspection?
  private(set) var hoverStatus = ""
  private var hoverGeneration = 0
  private var hoverPending: Task<Void, Never>?
  private var inspectionCache: [String:PolynomialInspection] = [:]
  private var lastPreviewTime = 0.0
  var source = "Bundled Lean export"
  private var cached: [PolynomialPoint] = []
  private var cacheKey = ""
  private var generation = 0
  private var requestID = 0
  private var pending: Task<Void, Never>?
  private let transport: Transport

  init(cloudData: Data? = nil, inspectionData: Data? = nil,
    transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
    self.transport = transport
    do {
      let bundledCloud = cloudData ?? Bundle.main.url(forResource: "polynomial-cloud-r6", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
      let bundledInspection = inspectionData ?? Bundle.main.url(forResource: "polynomial-default", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
      guard let cloudData = bundledCloud, let detailData = bundledInspection else { return }
      let cloud = try JSONDecoder().decode(PolynomialCloud.self, from: cloudData)
      let detail = try JSONDecoder().decode(PolynomialInspection.self, from: detailData)
      guard cloud.isValid, detail.isValid, cloud.radius == 6, !cloud.upperOnly,
        cloud.offset == 0, cloud.nextOffset == nil, detail.point == selected,
        [cloudData, detailData].allSatisfy({ data in
          guard let h = try? JSONDecoder().decode(PolynomialHeader.self, from: data) else { return false }
          return h.recognized && h.ok
        })
      else { throw URLError(.cannotParseResponse) }
      cached = cloud.points; points = cached; cacheKey = "6-false"; inspection = detail
      inspectionCache[detail.point.map(String.init).joined(separator:":")] = detail
    } catch { self.error = "Bundled Lean data unavailable: \(error.localizedDescription)" }
  }

  func select(_ point: [Int], pair: [Int]? = nil) {
    let bound = PolynomialIdentityBounds.coordinate
    guard point.count == 3, point.allSatisfy({ (-bound...bound).contains($0) }), point != [0,0,0] else {
      error = "Enter three nonzero-together integers in −\(bound)…\(bound)."; return
    }
    selected = point; paired = pair; refresh()
  }
  /// Entry follows the accepted Lean crop; Next may deliberately inspect a hidden multiple.
  func enter(_ point: [Int], asPair: Bool = false) {
    guard !busy, actionPreview == nil, points.contains(where: { $0.abc == point && isPointShown($0) }) else {
      error = "Choose a nonzero integer triple shown in the current accepted catalogue. Selection is unchanged."; return
    }
    select(asPair ? selected : point, pair: asPair ? point : nil)
  }
  func armPairNext(_ enabled:Bool) {
    guard !busy || !enabled else { return }
    if !enabled { cancelPairing(); return }
    cancelActionDrag(); hover(nil); pairNext = true; error = nil
  }
  func cancelPairing() {
    pairNext = false
    if armedPairRequest {
      pending?.cancel(); generation += 1; armedPairRequest = false; busy = false
      restoreAcceptedControls(); error = nil; status = "Pairing cancelled · accepted scene retained"
    }
  }
  /// Both Roots and RealityKit hits carry the exact signed catalogue identity.
  func pick(_ point:[Int]) {
    guard !busy, actionPreview == nil, points.contains(where: { $0.abc == point && isPointShown($0) }) else {
      error = "Choose a shown point in the accepted catalogue; selection is unchanged."; return
    }
    if pairNext {
      selected = inspection?.point ?? selected; paired = point
      refresh(disarmPairOnSuccess:true)
    } else { select(point) }
  }
  private func restoreAcceptedControls() {
    selected = inspection?.point ?? Self.nextSequence[0]; paired = displayedPair
    actionMatrix = action?.matrix ?? [1,0,0,1]
    radius = displayedRadius; catalogueMode = acceptedMode; upperOnly = acceptedUpperOnly
    whole = acceptedWhole; dust = acceptedDust
  }
  func isPointShown(_ point:PolynomialPoint) -> Bool {
    guard let shown = PolynomialMobius.mapDisplayCoordinates(rows:displayActionRows,
      SIMD3(Double(point.xyz[0]),Double(point.xyz[1]),Double(point.xyz[2]))) else { return false }
    return PolynomialRenderPlan.catalogueOpacity(point:point,shown:shown,catalogue:catalogue) > 0
  }
  var selectionShown: Bool { points.contains { $0.abc == inspection?.point && isPointShown($0) } }
  /// Hover is a separate, cancellable Lean inspection. It never changes selection or scene acceptance.
  func hover(_ point: [Int]?) {
    guard hoveredPoint != point else { return }
    hoverPending?.cancel(); hoverGeneration += 1; hoveredPoint = nil; hoverInspection = nil; hoverStatus = ""
    guard let point, points.contains(where: { $0.abc == point }) else { return }
    hoveredPoint = point
    let key = point.map(String.init).joined(separator:":")
    if let detail = inspectionCache[key] { hoverInspection = detail; hoverStatus = "Exact Lean inspection"; return }
    hoverStatus = "Inspecting in Lean…"
    let version = hoverGeneration
    hoverPending = Task {
      do {
        let detail: PolynomialInspection = try await call(["op":"inspect","point":point])
        guard detail.isValid, detail.point == point else { throw URLError(.cannotParseResponse) }
        guard !Task.isCancelled, version == hoverGeneration, hoveredPoint == point else { return }
        if inspectionCache.count >= 128 { inspectionCache.removeAll(keepingCapacity:true) }
        inspectionCache[key] = detail; hoverInspection = detail; hoverStatus = "Exact Lean inspection"
      } catch {
        guard !Task.isCancelled, version == hoverGeneration else { return }
        hoverStatus = "Hover inspection unavailable · selection unchanged"
      }
    }
  }
  func polynomialLabel(for point: [Int]) -> String? {
    if inspection?.point == point { return inspection?.displayPolynomial }
    if pairedInspection?.point == point { return pairedInspection?.displayPolynomial }
    return inspectionCache[point.map(String.init).joined(separator:":")]?.displayPolynomial
  }
  func waitForHover() async { await hoverPending?.value }
  func nextCoefficient() {
    let index = Self.nextSequence.firstIndex(of: selected) ?? -1
    select(Self.nextSequence[(index + 1) % Self.nextSequence.count])
  }
  func place(_ next: PolynomialPlacement) { cancelActionDrag(); placement = next; placementEpoch += 1 }
  func requestAction(_ matrix: [Int]) {
    guard matrix.count == 4, matrix.allSatisfy({ (-1_000_000...1_000_000).contains($0) }),
      matrix[0]*matrix[3]-matrix[1]*matrix[2] > 0 else {
      error = "Choose a bounded integer matrix with positive determinant."; return
    }
    cancelActionDrag(); actionMatrix = matrix; refresh(forceCatalogue:true)
  }
  func applyGenerator(_ g: [Int]) {
    guard !busy, g.count == 4, g.allSatisfy({ (-1...1).contains($0) }), g[0]*g[3]-g[1]*g[2] == 1 else { return }
    let m = action?.matrix ?? [1,0,0,1]
    let combined = [g[0]*m[0]+g[1]*m[2],g[0]*m[1]+g[1]*m[3],g[2]*m[0]+g[3]*m[2],g[2]*m[1]+g[3]*m[3]]
    let determinant = combined[0]*combined[3]-combined[1]*combined[2]
    let root = Int(Double(determinant).squareRoot().rounded())
    // Only an exactly integral normalized SL₂ matrix can relabel the signed lattice.
    if root > 0, root*root == determinant, combined.allSatisfy({ $0 % root == 0 }) {
      absorbAction(combined.map { $0/root })
    } else { requestAction(combined) }
  }
  func absorbAction(_ gamma: [Int]) {
    guard !busy else { return }
    guard gamma.count == 4, gamma.allSatisfy({ (-1_000_000...1_000_000).contains($0) }),
      gamma[0]*gamma[3]-gamma[1]*gamma[2] == 1 else {
      error = "Relabeling requires an integer matrix with determinant one; the accepted scene is unchanged."; return
    }
    refresh(absorbing:gamma)
  }
  func snapAction() {
    guard !busy else { return }
    guard let gamma = PolynomialMobius.nearestIntegral((action?.matrix ?? [1,0,0,1]).map(Double.init)) else {
      error = "No bounded Snap proposal; the accepted scene is unchanged."; return
    }
    absorbAction(gamma)
  }
  func setSnapOnRelease(_ enabled: Bool) {
    guard !busy else { return }
    snapOnRelease = enabled
    if enabled { snapAction() }
  }
  func nudgeAction(_ direction: SIMD2<Double>) {
    guard placement.isOrigin, !busy, PolynomialMobius.kleinToUpper(direction) != nil else { return }
    beginActionDrag(at:[0,0]); updateActionDrag(to:direction,force:true); commitActionDrag()
  }
  func beginActionDrag(at point: SIMD2<Double>) {
    guard placement.isOrigin, !busy else { return }
    cancelActionDrag(); hover(nil); dragSurface = .klein
    actionPreview = PolynomialActionPreview(matrix:(action?.matrix ?? [1,0,0,1]).map(Double.init),
      kleinPoint:point,inputRevision:sceneRevision)
    lastPreviewTime = 0; actionRevision += 1
  }
  func updateActionDrag(to point: SIMD2<Double>, force: Bool = false) {
    guard dragSurface == .klein else { return }
    guard placement.isOrigin, !busy, var preview = actionPreview,
      preview.inputRevision == sceneRevision else { cancelActionDrag(); return }
    // Bound rendering work on the Mac; this is an approximate interactive preview.
    let now = Date.timeIntervalSinceReferenceDate
    guard force || now-lastPreviewTime >= 0.08 else { return }
    if preview.update(kleinPoint:point) {
      actionPreview = preview; actionRevision += 1; lastPreviewTime = now; schedulePreviewCatalogue()
    }
  }
  /// Upper-half-plane dragging is independent of the ambient 3D viewpoint, as in the source Roots window.
  func beginRootsDrag(at point: SIMD2<Double>) {
    guard !busy else { return }
    cancelActionDrag(); hover(nil); dragSurface = .roots
    actionPreview = PolynomialActionPreview(matrix:(action?.matrix ?? [1,0,0,1]).map(Double.init),
      upperPoint:point,inputRevision:sceneRevision)
    lastPreviewTime = 0; actionRevision += 1
  }
  func updateRootsDrag(to point: SIMD2<Double>, force: Bool = false) {
    guard dragSurface == .roots else { return }
    guard !busy, var preview = actionPreview, preview.inputRevision == sceneRevision else { cancelActionDrag(); return }
    let now = Date.timeIntervalSinceReferenceDate
    guard force || now-lastPreviewTime >= 0.08 else { return }
    if preview.update(upperPoint:point) { actionPreview = preview; actionRevision += 1; lastPreviewTime = now; schedulePreviewCatalogue() }
  }
  func beginSpatialDrag(direction:SIMD3<Double>) {
    guard placement.isOrigin,!busy else { spatialInputStatus="Spatial drag requires Origin and an idle scene"; return }
    cancelActionDrag(); hover(nil); dragSurface = .spatial
    spatialEpoch=placementEpoch; spatialPlacement=placement; spatialNeedsAnchor=true; spatialMoved=false
    updateSpatialDrag(direction:direction,force:true)
  }
  func updateSpatialDrag(direction:SIMD3<Double>,force:Bool = false) {
    spatialInputCallbacks += 1
    guard dragSurface == .spatial else { spatialInputStatus="Spatial callback no longer owns preview"; return }
    guard placement.isOrigin,!busy,spatialEpoch == placementEpoch,spatialPlacement == placement else {
      cancelSpatialDrag(); spatialInputStatus="Placement changed · spatial preview cancelled"; return
    }
    guard let point=PolynomialSpatialInput.upperPoint(direction:direction) else {
      spatialNeedsAnchor=true; spatialInputStatus="Outside cone interior · waiting for a new anchor"; return
    }
    if spatialNeedsAnchor {
      actionPreview=PolynomialActionPreview(matrix:actionPreview?.matrix ?? displayActionMatrix,upperPoint:point,inputRevision:sceneRevision)
      spatialNeedsAnchor=false; spatialInputStatus="Spatial direction anchored"; actionRevision += 1; return
    }
    let now=Date.timeIntervalSinceReferenceDate
    guard force || now-lastPreviewTime >= 0.08,var preview=actionPreview else { return }
    let before=preview.matrix
    if preview.update(upperPoint:point) {
      actionPreview=preview; actionRevision += 1; lastPreviewTime=now
      spatialMoved = spatialMoved || preview.matrix != before
      spatialInputStatus="Spatial approximate move preview"; schedulePreviewCatalogue()
    }
  }
  @discardableResult func commitSpatialDrag() -> Bool {
    spatialInputReleases += 1
    guard dragSurface == .spatial,spatialMoved,placement.isOrigin,
      spatialEpoch == placementEpoch,spatialPlacement == placement else {
      cancelSpatialDrag(); spatialInputStatus="No moved spatial sample to commit"; return false
    }
    let accepted=commitDrag(from:.spatial)
    spatialInputStatus=accepted ? "Spatial release sent to Lean":"Spatial release rejected; accepted scene retained"
    return accepted
  }
  func cancelSpatialDrag() {
    guard dragSurface == .spatial else { return }
    cancelActionDrag(); spatialInputStatus="Spatial preview cancelled · accepted scene retained"
  }
  func cancelActionDrag() {
    cancelPreviewCatalogue()
    dragSurface = nil
    if actionPreview != nil { actionPreview = nil; actionRevision += 1 }
  }
  func cancelRootsDrag() { if dragSurface == .roots { cancelActionDrag() } }
  func cancelKleinDrag() { if dragSurface == .klein { cancelActionDrag() } }
  @discardableResult func commitRootsDrag() -> Bool { commitDrag(from:.roots) }
  @discardableResult func commitActionDrag() -> Bool { commitDrag(from:.klein) }
  private func commitDrag(from surface:DragSurface) -> Bool {
    guard dragSurface == surface, let preview = actionPreview else { return false }
    let matrix = snapOnRelease && preview.inputRevision == sceneRevision
      ? PolynomialMobius.nearestIntegral(preview.matrix) : preview.commitMatrix(ifRevision:sceneRevision)
    cancelActionDrag()
    guard let matrix else { error = "Drag sample could not be committed; accepted transform retained."; return false }
    if snapOnRelease { absorbAction(matrix) } else { requestAction(matrix) }
    return true
  }
  var displayActionRows: [Double] {
    if let preview = actionPreview, let rows = PolynomialMobius.coefficientRows(preview.matrix) { return rows }
    return action?.coefficientRowsApprox ?? [1,0,0,0,1,0,0,0,1]
  }
  /// Labels distinguish exact base descriptors from the currently drawn approximate image.
  var displayActionMatrix: [Double] { actionPreview?.matrix ?? action?.matrix.map(Double.init) ?? PolynomialMobius.identity }
  private var readoutMatrix: [Double] { displayActionMatrix }
  private var hasReadoutTransform: Bool {
    let g = readoutMatrix
    return g[1] != 0 || g[2] != 0 || g[0] != g[3]
  }
  private var shownReadoutPrefix: String { actionPreview == nil ? "shown ≈ " : "preview ≈ " }
  private func approximateLabel(_ value: Double) -> String {
    if value.isInfinite { return "∞" }
    return String(format:"%.3f",locale:Locale(identifier:"en_US_POSIX"),abs(value) < 0.0005 ? 0 : value)
  }
  var rootReadout: String {
    guard let detail = inspection else { return "" }
    guard hasReadoutTransform else { return detail.rootText }
    if let root = detail.root {
      let z = SIMD2(Double(root.real[0])/Double(root.real[1]),sqrt(Double(root.imaginary.radicand))/Double(root.imaginary.denominator))
      if let shown = PolynomialMobius.act(readoutMatrix,z) {
        return "Base \(detail.rootText) · \(shownReadoutPrefix)\(approximateLabel(shown.x)) + \(approximateLabel(shown.y))i"
      }
    } else if detail.kind == "exterior", let plane {
      let shown = plane.endpoints.compactMap { PolynomialMobius.actReal(readoutMatrix,$0.displayValue) }
      if shown.count == 2 { return "Base \(detail.rootText) · \(shownReadoutPrefix)\(shown.map(approximateLabel).joined(separator:" and "))" }
    }
    return "Base \(detail.rootText) · shown approximation unavailable"
  }
  var planeReadout: String {
    guard let plane else { return "" }
    let base = "\(plane.equation) · \(plane.endpoints.map(\.label).joined(separator:" and "))"
    guard hasReadoutTransform else { return base }
    let shown = plane.endpoints.compactMap { PolynomialMobius.actReal(readoutMatrix,$0.displayValue) }
    guard shown.count == 2 else { return "Base \(base) · shown approximation unavailable" }
    return "Base \(base) · \(shownReadoutPrefix)\(shown.map(approximateLabel).joined(separator:" and "))"
  }
  var actionStatus: String {
    if actionPreview != nil { return snapOnRelease ? "Approximate preview · release proposes integer Snap to Lean" : "Approximate drag preview · release sends a quantized sample to Lean" }
    if busy { return "Waiting for Lean · accepted transform remains visible" }
    return action == nil ? "Identity · base signed cloud" : "Lean accepted rational action · Δ preserved"
  }
  func reset() {
    cancelPairing(); setProjectionProgress(0); projectionHeightFraction = 0.6; showSourceScreen = true
    catalogueMode = .ball; whole = true; dust = false
    radius = 6; upperOnly = false; colorLower = false; showProjection = false; viewpoint = 0
    showCone = true; snapOnRelease = false; rootsResetRevision += 1; hover(nil)
    actionMatrix = [1,0,0,1]; place(.overview); select(Self.nextSequence[0])
  }
  func waitForPending() async { await pending?.value }

  func refresh(absorbing gamma: [Int]? = nil, forceCatalogue:Bool = false, disarmPairOnSuccess:Bool = false) {
    cancelActionDrag()
    pending?.cancel(); generation += 1; armedPairRequest = disarmPairOnSuccess
    let version = generation, original = gamma == nil ? selected : (inspection?.point ?? selected)
    let originalSecond = gamma == nil ? paired : displayedPair
    let desiredMatrix = gamma == nil ? actionMatrix : [1,0,0,1]
    let needsAction = gamma != nil || action != nil || actionMatrix != [1,0,0,1]
    let radius = radius, upper = upperOnly, mode = catalogueMode, whole = whole, dust = dust
    let key = mode == .ball ? "\(radius)-\(upper)"
      : "source:\(radius):\(desiredMatrix.map(String.init).joined(separator:",")):\(whole):\(dust)"
    busy = true; error = nil; status = "Waiting for Lean · previous scene visible"
    pending = Task {
      do {
        guard [4,6,8,10,12,16,24].contains(radius) else { throw URLError(.badURL) }
        var desired = original, second = originalSecond
        var absorbedDelta: Int?
        var secondDetail: PolynomialInspection?
        if let gamma {
          func boundedImage(_ receipt: PolynomialAction, point: [Int]) throws -> [Int] {
            guard receipt.matches(matrix:gamma,point:point), receipt.denominator == 1,
              let image = receipt.image, image != [0,0,0], image.allSatisfy({ (-PolynomialIdentityBounds.coordinate...PolynomialIdentityBounds.coordinate).contains($0) }) else {
              throw NSError(domain:"LeanPolynomial",code:2,userInfo:[NSLocalizedDescriptionKey:
                "Snap would exceed the signed inspection bound ±\(PolynomialIdentityBounds.coordinate), or Lean rejected its integer action. The entire accepted pair and transform are retained."])
            }
            return image
          }
          let primary: PolynomialAction = try await call(["op":"transform","matrix":gamma,"point":original])
          desired = try boundedImage(primary,point:original); absorbedDelta = primary.delta
          if let originalSecond {
            let secondary: PolynomialAction = try await call(["op":"transform","matrix":gamma,"point":originalSecond])
            let secondImage = try boundedImage(secondary,point:originalSecond); second = secondImage
            let inspected: PolynomialInspection = try await call(["op":"inspect","point":secondImage])
            guard inspected.isValid, inspected.point == secondImage, inspected.delta == secondary.delta else {
              throw URLError(.cannotParseResponse)
            }
            secondDetail = inspected
          }
        }
        var cloud = cached, sourceCatalogue = cachedCatalogue
        if cacheKey != key || (mode == .source && (forceCatalogue || gamma != nil)) {
          cloud = []; sourceCatalogue = nil
          var offset = 0, expectedTotal: Int?
          var seen = Set<String>()
          repeat {
            let pagePoints: [PolynomialPoint], total: Int, next: Int?
            if mode == .source {
              let page: PolynomialCataloguePage = try await call(["op":"catalogue","depth":radius,
                "matrix":desiredMatrix,"whole":whole,"dust":dust,"offset":offset,"limit":16384])
              guard page.matches(depth:radius,matrix:desiredMatrix,whole:whole,dust:dust,offset:offset),
                sourceCatalogue == nil || page.metadata.sameCatalogue(as:sourceCatalogue!) else { throw URLError(.cannotParseResponse) }
              sourceCatalogue = page.metadata; pagePoints = page.points; total = page.metadata.total; next = page.nextOffset
              if let previous = cloud.last, let first = pagePoints.first, offset != page.metadata.upperCount {
                guard previous.abc.lexicographicallyPrecedes(first.abc) else { throw URLError(.cannotParseResponse) }
              }
            } else {
              let page: PolynomialCloud = try await call(["op":"cloud","radius":radius,"upperOnly":upper,"offset":offset,"limit":16384])
              guard page.isValid, page.radius == radius, page.upperOnly == upper, page.offset == offset else { throw URLError(.cannotParseResponse) }
              pagePoints = page.points; total = page.total; next = page.nextOffset
            }
            guard total <= PolynomialRenderPlan.maximumPoints else {
              throw NSError(domain:"LeanPolynomial",code:3,userInfo:[NSLocalizedDescriptionKey:
                "This catalogue has \(total) points; the native renderer is bounded to \(PolynomialRenderPlan.maximumPoints). Previous scene retained."])
            }
            guard expectedTotal == nil || expectedTotal == total,
              !pagePoints.isEmpty || total == 0,
              pagePoints.allSatisfy({ seen.insert($0.id).inserted }) else { throw URLError(.cannotParseResponse) }
            expectedTotal = total; cloud += pagePoints
            guard let next else {
              guard cloud.count == total else { throw URLError(.cannotParseResponse) }
              break
            }
            guard next == cloud.count, next > offset else { throw URLError(.cannotParseResponse) }
            offset = next
          } while !Task.isCancelled
        }
        let detail: PolynomialInspection = try await call(["op":"inspect", "point":desired])
        guard detail.isValid, detail.point == desired, absorbedDelta == nil || absorbedDelta == detail.delta else { throw URLError(.cannotParseResponse) }
        if let second, secondDetail == nil {
          if let cached = inspectionCache[second.map(String.init).joined(separator:":")] { secondDetail = cached }
          else { secondDetail = try await call(["op":"inspect","point":second]) }
          guard secondDetail?.isValid == true, secondDetail?.point == second else { throw URLError(.cannotParseResponse) }
        }
        var acceptedAction: PolynomialAction?
        if needsAction {
          acceptedAction = try await call(["op":"transform", "matrix":desiredMatrix, "point":desired])
          guard acceptedAction?.matches(matrix:desiredMatrix,point:desired) == true,
            acceptedAction?.delta == detail.delta else { throw URLError(.cannotParseResponse) }
        }
        var cutting: PolynomialPlane?
        if let second {
          cutting = try await call(["op":"pair", "first":desired, "second":second])
        } else if detail.kind == "exterior" {
          cutting = try await call(["op":"plane", "normal":desired])
        }
        var members = Set<Int>()
        if let cutting {
          guard cutting.isValid, second == nil || cutting.isValidPair else { throw URLError(.cannotParseResponse) }
          if mode == .source {
            guard let sourceCatalogue else { throw URLError(.cannotParseResponse) }
            let membership: PolynomialCatalogueMembers = try await call(["op":"membersCatalogue","depth":radius,
              "matrix":desiredMatrix,"whole":whole,"dust":dust,"normal":cutting.normal])
            guard membership.matches(metadata:sourceCatalogue,normal:cutting.normal,points:cloud) else { throw URLError(.cannotParseResponse) }
            members = Set(membership.indices)
          } else {
            let membership: PolynomialMembers = try await call(["op":"members","radius":radius,"upperOnly":upper,"normal":cutting.normal])
            guard membership.radius == radius, membership.upperOnly == upper, membership.total == cloud.count,
              membership.count == membership.indices.count, Set(membership.indices).count == membership.count,
              membership.indices.allSatisfy({ cloud.indices.contains($0) && cloud[$0].delta < 0 })
            else { throw URLError(.cannotParseResponse) }
            members = Set(membership.indices)
          }
        }
        guard !Task.isCancelled, version == generation else { return }
        cached = cloud; cacheKey = key; cachedCatalogue = sourceCatalogue; catalogue = sourceCatalogue
        acceptedMode = mode; acceptedUpperOnly = upper; acceptedWhole = whole; acceptedDust = dust
        points = cloud.enumerated().map { index, p in
          PolynomialPoint(abc: p.abc, xyz: p.xyz, delta: p.delta, kind: p.kind, divisor: p.divisor,
            onPlane: mode == .source ? PolynomialSourceMorph.incident(p.abc,normal:cutting?.normal) : members.contains(index), necklace: members.contains(index))
        }
        hover(nil)
        inspectionCache[detail.point.map(String.init).joined(separator:":")] = detail
        if let secondDetail { inspectionCache[secondDetail.point.map(String.init).joined(separator:":")] = secondDetail }
        inspection = detail; pairedInspection = secondDetail; plane = cutting; displayedPair = second; displayedRadius = radius; sceneRevision += 1
        action = acceptedAction; actionRevision += 1
        selected = desired; paired = second; actionMatrix = desiredMatrix
        source = "Lean response from Mac"
        status = "Live Lean · \(points.count) signed triples" + (sourceCatalogue == nil ? "" : " · source depth \(radius)")
        if sourceCatalogue?.complete == false { status += " · source-limited catalogue" }
        busy = false; armedPairRequest = false
        if disarmPairOnSuccess { pairNext = false }
      } catch {
        guard !Task.isCancelled, version == generation else { return }
        busy = false; armedPairRequest = false; status = "Previous accepted scene · request not accepted"
        restoreAcceptedControls()
        self.error = error.localizedDescription
      }
    }
  }

  func setProjectionProgress(_ value:Double) {
    guard value.isFinite else { return }
    projectionTask?.cancel(); projectionAnimating = false
    projectionProgress = max(0,min(1,value)); showProjection = projectionProgress > 0
  }
  func setProjection(_ enabled:Bool,reducedMotion:Bool = false) {
    guard catalogue != nil else { showProjection = enabled; return }
    projectionTask?.cancel()
    let start=projectionProgress,target=enabled ? 1.0:0.0,duration=3.5*abs(target-start)
    showProjection = enabled
    guard !reducedMotion,duration > 0 else { setProjectionProgress(target); return }
    projectionAnimating = true
    projectionTask = Task {
      let beginning=Date.timeIntervalSinceReferenceDate
      while !Task.isCancelled {
        let elapsed=(Date.timeIntervalSinceReferenceDate-beginning)/duration
        projectionProgress = start+(target-start)*PolynomialSourceMorph.ease(elapsed)
        if elapsed >= 1 { break }
        try? await Task.sleep(for:.milliseconds(100))
      }
      if !Task.isCancelled {
        projectionProgress=target; projectionAnimating=false
        print("POLYNOMIAL_PROJECTION_ANIMATION: from=\(start) to=\(target) elapsed=\(Date.timeIntervalSinceReferenceDate-beginning) sourceDuration=\(duration)")
      }
    }
  }
  func waitForPreviewCatalogue() async { await previewCatalogueTask?.value }
  private func cancelPreviewCatalogue() {
    previewCatalogueGeneration += 1; previewCatalogueTask?.cancel(); previewCatalogueTask=nil
    pendingPreviewMatrix=nil; previewCatalogueStatus=""
    if previewPoints != nil { previewPoints=nil; previewCatalogue=nil; previewCatalogueRevision += 1 }
  }
  private func schedulePreviewCatalogue() {
    guard let accepted=catalogue,let preview=actionPreview else { return }
    guard let matrix=preview.commitMatrix(ifRevision:sceneRevision) else {
      previewCatalogueGeneration += 1; previewCatalogueTask?.cancel(); previewCatalogueTask=nil; pendingPreviewMatrix=nil
      previewCatalogueStatus="Preview sample cannot be quantized · last crop retained"; return
    }
    let basis=previewCatalogue?.matrix ?? accepted.matrix
    guard PolynomialCataloguePreviewPolicy.displacement(basis.map(Double.init),preview.matrix) >= PolynomialCataloguePreviewPolicy.threshold else {
      // A gesture can return to the displayed crop while an older, distant request is pending.
      // Invalidate that response without discarding the currently displayed preview.
      if previewCatalogueTask != nil {
        previewCatalogueGeneration += 1; previewCatalogueTask?.cancel(); previewCatalogueTask=nil; pendingPreviewMatrix=nil
        previewCatalogueStatus=previewPoints == nil ? "":"Live Lean preview crop · selection remains accepted"
      }
      return
    }
    pendingPreviewMatrix=matrix
    guard previewCatalogueTask == nil else { return }
    let token=previewCatalogueGeneration,revision=sceneRevision,normal=plane?.normal
    previewCatalogueTask = Task {
      while !Task.isCancelled,token == previewCatalogueGeneration,let candidate=pendingPreviewMatrix {
        pendingPreviewMatrix=nil
        let wait=0.15-(Date.timeIntervalSinceReferenceDate-lastCatalogueStart)
        if wait > 0 { try? await Task.sleep(for:.seconds(wait)) }
        guard !Task.isCancelled,token == previewCatalogueGeneration else { return }
        lastCatalogueStart=Date.timeIntervalSinceReferenceDate
        previewCatalogueStatus="Lean preview catalogue pending · last accepted crop visible"
        do {
          let loaded=try await loadPreviewCatalogue(matrix:candidate,accepted:accepted,normal:normal)
          guard !Task.isCancelled,token == previewCatalogueGeneration,sceneRevision == revision,
            actionPreview != nil else { return }
          if pendingPreviewMatrix == nil || pendingPreviewMatrix == candidate {
            pendingPreviewMatrix=nil
            previewPoints=loaded.0; previewCatalogue=loaded.1; previewCatalogueRevision += 1
            previewCatalogueAcceptances += 1
            print("POLYNOMIAL_PREVIEW_CATALOGUE: matrix=\(candidate) points=\(loaded.0.count) acceptedScene=\(sceneRevision) previewOnly=true")
            previewCatalogueStatus="Live Lean preview crop · \(loaded.0.count) signed identities · selection remains accepted"
          }
        } catch {
          guard !Task.isCancelled,token == previewCatalogueGeneration else { return }
          previewCatalogueStatus="Preview recrop unavailable · previous preview retained"
        }
      }
      if token == previewCatalogueGeneration { previewCatalogueTask=nil }
    }
  }
  private func loadPreviewCatalogue(matrix:[Int],accepted:PolynomialCatalogueMetadata,normal:[Int]?) async throws -> ([PolynomialPoint],PolynomialCatalogueMetadata) {
    var points:[PolynomialPoint]=[],metadata:PolynomialCatalogueMetadata?,offset=0,seen=Set<String>()
    repeat {
      let page:PolynomialCataloguePage=try await call(["op":"catalogue","depth":accepted.depth,
        "matrix":matrix,"whole":accepted.whole,"dust":accepted.dust,"offset":offset,"limit":16384])
      guard page.matches(depth:accepted.depth,matrix:matrix,whole:accepted.whole,dust:accepted.dust,offset:offset),
        metadata == nil || page.metadata.sameCatalogue(as:metadata!),page.metadata.total <= PolynomialRenderPlan.maximumPoints,
        !page.points.isEmpty || page.metadata.total == 0,page.points.allSatisfy({seen.insert($0.id).inserted}) else { throw URLError(.cannotParseResponse) }
      if let previous=points.last,let first=page.points.first,offset != page.metadata.upperCount {
        guard previous.abc.lexicographicallyPrecedes(first.abc) else { throw URLError(.cannotParseResponse) }
      }
      points += page.points; metadata=page.metadata
      guard let next=page.nextOffset else {
        guard points.count == page.metadata.total else { throw URLError(.cannotParseResponse) }; break
      }
      guard next == points.count,next > offset else { throw URLError(.cannotParseResponse) }; offset=next
    } while !Task.isCancelled
    try Task.checkCancellation()
    guard let metadata else { throw URLError(.cannotParseResponse) }
    if let normal {
      let membership:PolynomialCatalogueMembers=try await call(["op":"membersCatalogue","depth":accepted.depth,
        "matrix":matrix,"whole":accepted.whole,"dust":accepted.dust,"normal":normal])
      guard membership.matches(metadata:metadata,normal:normal,points:points) else { throw URLError(.cannotParseResponse) }
      let indices=Set(membership.indices)
      points=points.enumerated().map { i,p in PolynomialPoint(abc:p.abc,xyz:p.xyz,delta:p.delta,kind:p.kind,
        divisor:p.divisor,onPlane:PolynomialSourceMorph.incident(p.abc,normal:normal),necklace:indices.contains(i)) }
    }
    return (points,metadata)
  }

  private func call<T: Decodable>(_ input: [String: Any]) async throws -> T {
    try Task.checkCancellation()
    guard let root = URL(string: server), ["http", "https"].contains(root.scheme), root.host != nil else { throw URLError(.badURL) }
    requestID += 1; let id = requestID
    var object = input; object["id"] = id
    var request = URLRequest(url: root.appendingPathComponent("api/polynomial"))
    request.httpMethod = "POST"; request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: object)
    let (data, response) = try await transport(request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let header = try JSONDecoder().decode(PolynomialHeader.self, from: data)
    guard header.recognized, header.id == id else { throw URLError(.cannotParseResponse) }
    guard header.ok else { throw NSError(domain: "LeanPolynomial", code: 1, userInfo: [NSLocalizedDescriptionKey: header.error ?? "Lean rejected this request."]) }
    return try JSONDecoder().decode(T.self, from: data)
  }
}
