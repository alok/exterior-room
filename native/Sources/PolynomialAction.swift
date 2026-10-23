// SPDX-License-Identifier: GPL-3.0-or-later
// Preview formulas adapted from FareyVision 63ad115422ab1141ca6d06732572385414b7a5cf,
// Farey/WebXR/mobius.js, after Harriss, Stange and Trettel, Algebraic Number Starscapes §4.2.2.
// Polar Snap follows Farey/WebXR/mobius.js at 2cd549a45ddb6056cf3596404754d96ad9e7132c.
// Alok Singh with OpenAI Codex, 2026-10-23: bounded native transport and explicitly approximate preview.
import Foundation

/// Exact identity inspection is independent of the rendered cloud's radius limit.
/// With |Mᵢⱼ|≤10⁶, all coefficient/XYZ numerators stay ≤6·1024·10¹² < 2⁵³−1.
enum PolynomialIdentityBounds {
  static let coordinate = 1024
  static let delta = 5 * coordinate * coordinate
  static let actionNumerator = 6_144_000_000_000_000
  static let normal = 4 * coordinate * coordinate
}

/// Exact integers received from Lean. Decoding/consistency checks are not kernel proof checking.
/// No locally computed preview is converted into an accepted PolynomialAction.
struct PolynomialAction: Decodable, Sendable {
  let ok: Bool, id: Int
  let schema: String, engine: String, sourceCommit: String
  let actionSchema: String, actionSourceCommit: String
  let matrix: [Int], denominator: Int, coefficientRows: [Int]
  let point: [Int], imageNumerator: [Int], xyzNumerator: [Int], delta: Int
  let image: [Int]?
  let checks: [String: Bool]

  private enum CodingKeys: String, CodingKey {
    case ok, id, schema, engine, sourceCommit, actionSchema, actionSourceCommit
    case matrix, denominator, coefficientRows, point, imageNumerator, xyzNumerator, delta, image, checks
  }
  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    ok = try c.decode(Bool.self, forKey: .ok); id = try c.decode(Int.self, forKey: .id)
    schema = try c.decode(String.self, forKey: .schema); engine = try c.decode(String.self, forKey: .engine)
    sourceCommit = try c.decode(String.self, forKey: .sourceCommit)
    actionSchema = try c.decode(String.self, forKey: .actionSchema)
    actionSourceCommit = try c.decode(String.self, forKey: .actionSourceCommit)
    matrix = try c.decode([Int].self, forKey: .matrix); denominator = try c.decode(Int.self, forKey: .denominator)
    coefficientRows = try c.decode([Int].self, forKey: .coefficientRows)
    point = try c.decode([Int].self, forKey: .point)
    imageNumerator = try c.decode([Int].self, forKey: .imageNumerator)
    xyzNumerator = try c.decode([Int].self, forKey: .xyzNumerator)
    delta = try c.decode(Int.self, forKey: .delta)
    // Null is meaningful; omission is a malformed response, not an integer-image decision.
    image = try c.decode([Int]?.self, forKey: .image)
    checks = try c.decode([String: Bool].self, forKey: .checks)
  }

  var isValid: Bool {
    guard ok, id >= 0, schema == "polynomial-space-v1", engine == "Lean 4.35.0-rc3",
      sourceCommit == "ca809d2975a37a318a425e4b9dd73560b07faf39",
      actionSchema == "polynomial-mobius-v1",
      actionSourceCommit == "63ad115422ab1141ca6d06732572385414b7a5cf",
      matrix.count == 4, matrix.allSatisfy({ (-1_000_000...1_000_000).contains($0) }),
      (1...2_000_000_000_000).contains(denominator), coefficientRows.count == 9,
      coefficientRows.allSatisfy({ (-2_000_000_000_000...2_000_000_000_000).contains($0) }),
      point.count == 3, point != [0,0,0], point.allSatisfy({ (-PolynomialIdentityBounds.coordinate...PolynomialIdentityBounds.coordinate).contains($0) }),
      imageNumerator.count == 3, xyzNumerator.count == 3,
      (imageNumerator + xyzNumerator).allSatisfy({ (-PolynomialIdentityBounds.actionNumerator...PolynomialIdentityBounds.actionNumerator).contains($0) }),
      (-PolynomialIdentityBounds.delta...PolynomialIdentityBounds.delta).contains(delta),
      checks["positiveDeterminant"] == true, checks["discriminantPreserved"] == true,
      checks.values.allSatisfy({ $0 })
    else { return false }
    let p = matrix[0], q = matrix[1], r = matrix[2], s = matrix[3]
    guard denominator == p*s-q*r,
      coefficientRows == [s*s,-r*s,r*r,-2*q*s,p*s+q*r,-2*p*r,q*q,-p*q,p*p]
    else { return false }
    // Bounds above make these transport-consistency products safe in 64-bit Int.
    let receivedImage = (0..<3).map { row in
      coefficientRows[row*3]*point[0] + coefficientRows[row*3+1]*point[1] + coefficientRows[row*3+2]*point[2]
    }
    guard imageNumerator == receivedImage,
      xyzNumerator == [-receivedImage[1],receivedImage[0]+receivedImage[2],receivedImage[2]-receivedImage[0]],
      delta == point[1]*point[1]-4*point[0]*point[2]
    else { return false }
    let integral = receivedImage.allSatisfy { $0 % denominator == 0 }
    return integral ? image == receivedImage.map { $0 / denominator } : image == nil
  }

  func matches(matrix expectedMatrix: [Int], point expectedPoint: [Int]) -> Bool {
    isValid && matrix == expectedMatrix && point == expectedPoint
  }
  /// Floating-point rendering of the received rational matrix J(M)/det(M).
  var coefficientRowsApprox: [Double]? {
    guard isValid else { return nil }
    return coefficientRows.map { Double($0) / Double(denominator) }
  }
  func mapCoefficients(_ abc: SIMD3<Double>) -> SIMD3<Double>? {
    guard let rows = coefficientRowsApprox else { return nil }
    return PolynomialMobius.applyRows(rows, abc)
  }
  func mapDisplay(_ xyz: SIMD3<Float>) -> SIMD3<Float>? {
    guard let rows = coefficientRowsApprox else { return nil }
    return PolynomialMobius.mapDisplay(rows: rows, xyz)
  }
}

/// Renderer-only Double math. These values and pointer paths are outside Lean's proof boundary.
enum PolynomialMobius {
  static let identity: [Double] = [1,0,0,1]
  private static func matrix(_ g: [Double]) -> Bool { g.count == 4 && g.allSatisfy(\.isFinite) }
  private static func upper(_ z: SIMD2<Double>) -> Bool { z.x.isFinite && z.y.isFinite && z.y > 0 }

  static func multiply(_ g: [Double], _ h: [Double]) -> [Double]? {
    guard matrix(g), matrix(h) else { return nil }
    let result = [g[0]*h[0]+g[1]*h[2],g[0]*h[1]+g[1]*h[3],g[2]*h[0]+g[3]*h[2],g[2]*h[1]+g[3]*h[3]]
    return result.allSatisfy(\.isFinite) ? result : nil
  }
  /// Scale first to avoid overflow; refuse nearly singular preview matrices rather than jump to identity.
  static func normalize(_ g: [Double]) -> [Double]? {
    guard matrix(g), let scale = g.map({ abs($0) }).max(), scale > 0 else { return nil }
    let h = g.map { $0 / scale }, determinant = h[0]*h[3]-h[1]*h[2]
    guard determinant.isFinite, determinant > 1e-12 else { return nil }
    let divisor = sqrt(determinant), result = h.map { $0 / divisor }
    return result.allSatisfy(\.isFinite) ? result : nil
  }
  static func inverse(_ g: [Double]) -> [Double]? {
    guard let h = normalize(g) else { return nil }
    return [h[3],-h[1],-h[2],h[0]]
  }
  static func act(_ g: [Double], _ z: SIMD2<Double>) -> SIMD2<Double>? {
    guard let h = normalize(g), upper(z) else { return nil }
    let nx = h[0]*z.x+h[1], ny = h[0]*z.y, dx = h[2]*z.x+h[3], dy = h[2]*z.y
    let denominator = dx*dx+dy*dy
    guard denominator.isFinite, denominator > 0 else { return nil }
    let result = SIMD2((nx*dx+ny*dy)/denominator,(ny*dx-nx*dy)/denominator)
    return upper(result) ? result : nil
  }
  /// Approximate action on the real projective line, including its single point at infinity.
  static func actReal(_ g: [Double], _ t: Double) -> Double? {
    guard let h = normalize(g), !t.isNaN else { return nil }
    if t.isInfinite { return h[2] == 0 ? .infinity : h[0]/h[2] }
    let numerator = h[0]*t+h[1], denominator = h[2]*t+h[3]
    guard numerator.isFinite, denominator.isFinite else { return nil }
    return denominator == 0 ? .infinity : numerator/denominator
  }
  static func toI(_ z: SIMD2<Double>) -> [Double]? {
    guard upper(z) else { return nil }
    let t = sqrt(z.y), result = [1/t,-z.x/t,0,t]
    return matrix(result) ? result : nil
  }
  static func fromI(_ w: SIMD2<Double>) -> [Double]? {
    guard upper(w) else { return nil }
    let m = (w.x*w.x+w.y*w.y)/w.y, n = w.x/w.y, k = 1/w.y, t = sqrt(m+k+2)
    return normalize([(m+1)/t,n/t,n/t,(k+1)/t])
  }
  static func transvection(_ z0: SIMD2<Double>, _ z1: SIMD2<Double>) -> [Double]? {
    guard let h = toI(z0), let hInverse = inverse(h), let w = act(h,z1), let move = fromI(w),
      let right = multiply(move,h), let result = multiply(hInverse,right) else { return nil }
    return normalize(result)
  }
  static func dragStep(_ g: [Double], from z0: SIMD2<Double>, to z1: SIMD2<Double>) -> [Double]? {
    guard let step = transvection(z0,z1), let combined = multiply(step,g) else { return nil }
    return normalize(combined)
  }
  static func coefficientRows(_ g: [Double]) -> [Double]? {
    guard let h = normalize(g) else { return nil }
    let p = h[0],q = h[1],r = h[2],s = h[3]
    let rows = [s*s,-r*s,r*r,-2*q*s,p*s+q*r,-2*p*r,q*q,-p*q,p*p]
    return rows.allSatisfy(\.isFinite) ? rows : nil
  }
  static func applyRows(_ rows: [Double], _ abc: SIMD3<Double>) -> SIMD3<Double>? {
    guard rows.count == 9, rows.allSatisfy(\.isFinite), [abc.x,abc.y,abc.z].allSatisfy(\.isFinite) else { return nil }
    let result = SIMD3(rows[0]*abc.x+rows[1]*abc.y+rows[2]*abc.z,
      rows[3]*abc.x+rows[4]*abc.y+rows[5]*abc.z,rows[6]*abc.x+rows[7]*abc.y+rows[8]*abc.z)
    return [result.x,result.y,result.z].allSatisfy(\.isFinite) ? result : nil
  }
  static func mapDisplay(rows: [Double], _ xyz: SIMD3<Float>) -> SIMD3<Float>? {
    guard let image = mapDisplayCoordinates(rows:rows,SIMD3<Double>(Double(xyz.x),Double(xyz.y),Double(xyz.z))) else { return nil }
    let mapped = SIMD3<Float>(Float(image.x),Float(image.y),Float(image.z))
    return [mapped.x,mapped.y,mapped.z].allSatisfy(\.isFinite) ? mapped : nil
  }
  static func mapDisplayCoordinates(rows: [Double], _ xyz: SIMD3<Double>) -> SIMD3<Double>? {
    guard let image = applyRows(rows,SIMD3((xyz.y-xyz.z)/2,-xyz.x,(xyz.y+xyz.z)/2)) else { return nil }
    let mapped = SIMD3<Double>(-image.y,image.x+image.z,image.z-image.x)
    return [mapped.x,mapped.y,mapped.z].allSatisfy(\.isFinite) ? mapped : nil
  }
  /// For the normalized Lorentz action F, F⁻ᵀ = QFQ with Q = diag(1,-1,1).
  /// Convert the accepted rational rows (or declared approximate preview) only at this renderer boundary.
  /// This transports a Cartesian plane normal; treating it as an ordinary point would be incorrect.
  static func mapPlaneNormal(rows: [Double], _ normal: SIMD3<Double>) -> SIMD3<Double>? {
    guard let image = mapDisplayCoordinates(rows:rows,[normal.x,-normal.y,normal.z]) else { return nil }
    return [image.x,-image.y,image.z]
  }
  static func kleinToUpper(_ uv: SIMD2<Double>) -> SIMD2<Double>? {
    guard uv.x.isFinite, uv.y.isFinite else { return nil }
    let h = 1-uv.x*uv.x-uv.y*uv.y
    guard h > 0, 1-uv.y > 0 else { return nil }
    let result = SIMD2(uv.x/(1-uv.y),sqrt(h)/(1-uv.y))
    return upper(result) ? result : nil
  }
  static func upperToKlein(_ z: SIMD2<Double>) -> SIMD2<Double>? {
    guard upper(z) else { return nil }
    let n = z.x*z.x+z.y*z.y
    guard n.isFinite else { return nil }
    let result = SIMD2(2*z.x/(1+n),(n-1)/(1+n))
    return result.x.isFinite && result.y.isFinite ? result : nil
  }
  /// Polar rotation about i, folded modulo ±I. Renderer approximation, not a Lean result.
  /// Source criterion: FareyVision 2cd549a45ddb6056cf3596404754d96ad9e7132c WebXR/mobius.js.
  static func polarAngle(_ g: [Double]) -> Double? {
    guard g.count == 4, g.allSatisfy(\.isFinite) else { return nil }
    let numerator = g[2]-g[1], denominator = g[0]+g[3]
    guard numerator.isFinite, denominator.isFinite else { return nil }
    var theta = atan2(numerator,denominator)
    while theta > .pi/2 { theta -= .pi }
    while theta <= -.pi/2 { theta += .pi }
    return theta
  }
  /// Renderer-only Snap proposal: reduce g·i to the canonical modular cell, then choose γ or
  /// γS by the smaller residual polar rotation, with the source's 1e−12 tie tolerance.
  /// Matches floor(x + 0.5) and canonical ± sign, with bounded native arithmetic and refusal
  /// on failure to converge. Lean must accept the integer request separately; this is not a
  /// proof of a globally nearest lattice element.
  static func nearestIntegral(_ g: [Double]) -> [Int]? {
    guard let normalized = normalize(g), var w = act(normalized, [0,1]) else { return nil }
    let limit = 1_000_000
    func bounded(_ values: [Int]) -> Bool { values.allSatisfy { (-limit...limit).contains($0) } }
    var m = [1,0,0,1], converged = false
    for _ in 0..<200 {
      // Swift's nearest rounding differs from JS Math.round for negative half-integers.
      let rounded = floor(w.x + 0.5)
      guard rounded.isFinite, (-Double(limit)...Double(limit)).contains(rounded) else { return nil }
      let n = Int(rounded)
      if n != 0 {
        w.x -= Double(n)
        // n and m are bounded by 10⁶, so products and differences fit safely in Int64.
        m = [m[0]-n*m[2],m[1]-n*m[3],m[2],m[3]]
        guard bounded(m) else { return nil }
      }
      let norm = w.x*w.x + w.y*w.y
      guard norm.isFinite else { return nil }
      if norm < 1-1e-12 {
        guard let inverted = act([0,-1,1,0],w) else { return nil }
        w = inverted; m = [-m[2],-m[3],m[0],m[1]]
      } else {
        converged = true; break
      }
    }
    guard converged else { return nil }
    let gamma = [m[3],-m[1],-m[2],m[0]]
    let gammaS = [gamma[1],-gamma[0],gamma[3],-gamma[2]]
    func turn(_ candidate: [Int]) -> Double? {
      let inverse = [candidate[3],-candidate[1],-candidate[2],candidate[0]].map(Double.init)
      guard let residual = multiply(inverse,normalized), let angle = polarAngle(residual) else { return nil }
      return abs(angle)
    }
    guard let firstTurn = turn(gamma), let secondTurn = turn(gammaS) else { return nil }
    let chosen = secondTurn < firstTurn-1e-12 ? gammaS : gamma
    let trace = chosen[0]+chosen[3], leading = chosen[0] != 0 ? chosen[0] : chosen[2]
    let best = trace > 0 || (trace == 0 && leading > 0) ? chosen : chosen.map { -$0 }
    guard bounded(best),
      best[0]*best[3]-best[1]*best[2] == 1 else { return nil }
    return best
  }
  /// Quantization is a renderer choice, not a proof about the original continuous drag.
  /// Lean receives this declared integer matrix and checks its exact rational action separately.
  static func quantizedMatrix(_ g: [Double], precision: Int = 10_000) -> [Int]? {
    guard (1...1_000_000).contains(precision), let h = normalize(g),
      let largest = h.map({ abs($0) }).max(), largest > 0 else { return nil }
    let scale = min(Double(precision),1_000_000/largest)
    let rounded = h.map { ($0*scale).rounded(.toNearestOrAwayFromZero) }
    guard rounded.allSatisfy({ $0.isFinite && (-1_000_000...1_000_000).contains($0) }) else { return nil }
    var result = rounded.map(Int.init)
    func gcd(_ a: Int,_ b: Int) -> Int {
      var x = abs(a), y = abs(b)
      while y != 0 { (x,y) = (y,x%y) }
      return x
    }
    let divisor = result.reduce(0,gcd)
    guard divisor > 0 else { return nil }
    result = result.map { $0/divisor }
    guard result[0]*result[3]-result[1]*result[2] > 0 else { return nil }
    return result
  }
}

/// Disposable preview value. Cancellation/revision checks produce no commit request or accepted result.
struct PolynomialActionPreview: Sendable, Equatable {
  let inputRevision: Int
  let initialMatrix: [Double]
  private(set) var matrix: [Double]
  private(set) var isCancelled = false
  private var lastUpper: SIMD2<Double>

  init?(matrix: [Double], kleinPoint: SIMD2<Double>, inputRevision: Int) {
    guard let start = PolynomialMobius.kleinToUpper(kleinPoint) else { return nil }
    self.init(matrix:matrix,upperPoint:start,inputRevision:inputRevision)
  }
  init?(matrix: [Double], upperPoint: SIMD2<Double>, inputRevision: Int) {
    guard inputRevision >= 0, let initial = PolynomialMobius.normalize(matrix),
      upperPoint.x.isFinite, upperPoint.y.isFinite, upperPoint.y > 1e-6 else { return nil }
    self.inputRevision = inputRevision; initialMatrix = initial; self.matrix = initial; lastUpper = upperPoint
  }
  @discardableResult mutating func update(kleinPoint: SIMD2<Double>) -> Bool {
    guard let next = PolynomialMobius.kleinToUpper(kleinPoint) else { return false }
    return update(upperPoint:next)
  }
  @discardableResult mutating func update(upperPoint next: SIMD2<Double>) -> Bool {
    guard !isCancelled, next.x.isFinite, next.y.isFinite, next.y > 1e-6,
      let moved = PolynomialMobius.dragStep(matrix,from:lastUpper,to:next) else { return false }
    matrix = moved; lastUpper = next; return true
  }
  mutating func cancel() { isCancelled = true; matrix = initialMatrix }
  func commitMatrix(ifRevision revision: Int) -> [Int]? {
    guard !isCancelled, revision == inputRevision else { return nil }
    return PolynomialMobius.quantizedMatrix(matrix)
  }
}
