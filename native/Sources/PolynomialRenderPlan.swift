// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23. Approximate rendering of accepted Lean data only.
import Foundation

/// CPU-side instance and picking data. Signed identity is carried from the accepted catalogue;
/// it is never recovered by rounding or inverting a floating-point position.
enum PolynomialRenderPlan {
  static let maximumPoints = 40_000
  static let collisionChunkSize = 8_192 // Six vertices each stay below UInt16.max.
  struct Glyph: Sendable {
    let point: PolynomialPoint
    let position: SIMD3<Float>
    let factor: Float
    let colorKey: UInt32
    let opacity: Double
    var collisionRadius: Float { max(0.0125,0.01125*factor) }
  }
  struct Snapshot: Sendable {
    let glyphs: [Glyph]
    let batches: [UInt32:[Int]]
    let radialPositions: [SIMD3<Float>]
    let scale: Float
    /// The closest accepted glyph to a collision-surface hit. This is approximate UI picking.
    func pick(at location:SIMD3<Float>, range:Range<Int>? = nil) -> PolynomialPoint? {
      guard (0..<3).allSatisfy({ location[$0].isFinite }) else { return nil }
      var nearest:Int?, distance = Float.infinity
      for index in range ?? glyphs.indices {
        guard glyphs.indices.contains(index) else { continue }
        let glyph = glyphs[index]
        guard glyph.opacity > 0 else { continue }
        let d = location-glyph.position
        let squared = d.x*d.x+d.y*d.y+d.z*d.z
        guard squared <= glyph.collisionRadius*glyph.collisionRadius*1.01 else { continue }
        if squared < distance { nearest = index; distance = squared }
      }
      return nearest.map { glyphs[$0].point }
    }
  }
  struct CollisionChunk: Sendable {
    let range: Range<Int>
    let positions: [SIMD3<Float>]
    let indices: [UInt16]
  }
  static func colorKey(_ color:SIMD3<Double>) -> UInt32 {
    let bytes = (color*255).rounded(.toNearestOrAwayFromZero)
    return UInt32(max(0,min(255,bytes.x)))<<16 | UInt32(max(0,min(255,bytes.y)))<<8 | UInt32(max(0,min(255,bytes.z)))
  }
  static func color(_ key:UInt32) -> SIMD3<Double> {
    SIMD3(Double((key>>16)&255),Double((key>>8)&255),Double(key&255))/255
  }
  static func make(points:[PolynomialPoint], rows:[Double], radius:Int, origin:Bool,
    starSize:Double, colorLower:Bool, palette:String, normal:SIMD3<Double>?, keep:[Int], projection:Bool, catalogue:PolynomialCatalogueMetadata? = nil) -> Snapshot? {
    guard radius > 0, points.count <= maximumPoints, starSize.isFinite, starSize > 0 else { return nil }
    let scale = Float(0.96/Double(radius))
    var glyphs:[Glyph] = []; glyphs.reserveCapacity(points.count)
    var batches:[UInt32:[Int]] = [:], radial:[SIMD3<Float>] = []
    if projection { radial.reserveCapacity(points.count/3) }
    for p in points {
      let base = SIMD3(Double(p.xyz[0]),Double(p.xyz[1]),Double(p.xyz[2]))
      guard let shown = PolynomialMobius.mapDisplayCoordinates(rows:rows,base),
        (0..<3).allSatisfy({ shown[$0].isFinite }) else { return nil }
      let position = SIMD3(Float(shown.x),Float(shown.y),Float(shown.z))*scale
      let baseFactor = origin && p.delta < 0
        ? Float(0.4*pow(Double(-p.delta),0.25)/sqrt(max(0.000001,abs(shown.y))))
        : PolynomialAppearance.radiusFactor(p,colorLower:colorLower,atOrigin:false)
      let factor = Float(starSize)*baseFactor*(p.necklace && p.kind == 2 && !origin ? 1.35:1)
      let fade = normal.map { PolynomialAppearance.focusFade(p,position:shown,normal:$0,radius:radius,keep:keep) } ?? 1
      guard (0..<3).allSatisfy({ position[$0].isFinite }), factor.isFinite, factor > 0 else { return nil }
      let opacity = catalogueOpacity(point:p,shown:shown,catalogue:catalogue)
      let key = colorKey(PolynomialAppearance.color(p,colorLower:colorLower,palette:palette)*fade*opacity)
      if opacity > 0 { batches[key,default:[]].append(glyphs.count) }
      glyphs.append(Glyph(point:p,position:position,factor:factor,colorKey:key,opacity:opacity))
      if projection, opacity > 0, p.delta < 0, catalogue == nil || (p.kind == 2 && p.divisor == 1), abs(position.y) > 0.000001 {
        let projected = position*(4*scale/position.y)
        guard (0..<3).allSatisfy({ projected[$0].isFinite }) else { return nil }
        radial.append(projected)
      }
    }
    return Snapshot(glyphs:glyphs,batches:batches,radialPositions:radial,scale:scale)
  }
  /// Audited source display clipping; this does not change the accepted signed catalogue.
  static func catalogueOpacity(point:PolynomialPoint,shown:SIMD3<Double>,catalogue:PolynomialCatalogueMetadata?) -> Double {
    guard let catalogue else { return 1 }
    let cutoff = Double(point.kind == 2 ? catalogue.depth : catalogue.otherRadius)
    guard cutoff > 0 else { return 0 }
    // Match the browser's Float32 display buffer before CPU visibility/picking.
    // Exact boundary points must not leave sub-ulp positive opacity and invisible hit proxies.
    let display = SIMD3(Double(Float(shown.x)),Double(Float(shown.y)),Double(Float(shown.z)))
    let distance = point.kind == 2 ? display.y : hypot(hypot(display.x,display.y),display.z)
    guard distance.isFinite, distance < cutoff else { return 0 }
    let t = max(0,min(1,(distance-0.86*cutoff)/((1-0.86)*cutoff)))
    return 1-t*t*(3-2*t)
  }
  static func collisionChunks(_ snapshot:Snapshot) -> [CollisionChunk] {
    // Octahedral hit proxies; the visible glyph is a separate sphere instance.
    let directions:[SIMD3<Float>] = [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]
    let faces:[UInt16] = [2,4,0, 2,1,4, 2,5,1, 2,0,5, 3,0,4, 3,4,1, 3,1,5, 3,5,0]
    return stride(from:0,to:snapshot.glyphs.count,by:collisionChunkSize).map { start in
      let range = start..<min(start+collisionChunkSize,snapshot.glyphs.count)
      var positions:[SIMD3<Float>] = []; positions.reserveCapacity(range.count*6)
      var indices:[UInt16] = []; indices.reserveCapacity(range.count*24)
      for i in range {
        let glyph = snapshot.glyphs[i]
        guard glyph.opacity > 0 else { continue }
        let offset = UInt16(positions.count)
        positions += directions.map { glyph.position+$0*glyph.collisionRadius }
        indices += faces.map { offset+$0 }
      }
      return CollisionChunk(range:range,positions:positions,indices:indices)
    }.filter { !$0.indices.isEmpty }
  }
  /// Shared low-poly sphere. Unlit material preserves the existing semantic color and physical radius.
  static func sphere(radius:Float = 0.0075) -> (positions:[SIMD3<Float>],indices:[UInt32]) {
    let slices = 12, rings = 8
    var positions:[SIMD3<Float>] = [], indices:[UInt32] = []
    for ring in 0...rings {
      let latitude = Float(ring)*Float.pi/Float(rings)
      for slice in 0..<slices {
        let longitude = Float(slice)*2*Float.pi/Float(slices)
        positions.append(radius*SIMD3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude)))
      }
    }
    for ring in 0..<rings {
      for slice in 0..<slices {
        let a = UInt32(ring*slices+slice),b = UInt32(ring*slices+(slice+1)%slices)
        let c = a+UInt32(slices),d = b+UInt32(slices)
        if ring > 0 { indices += [a,b,c] }
        if ring < rings-1 { indices += [b,d,c] }
      }
    }
    return (positions,indices)
  }
}
