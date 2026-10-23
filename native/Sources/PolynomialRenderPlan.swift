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
    let batches: [UInt64:[Int]]
    let materialAlpha:[UInt64:Double]
    let radialPositions: [SIMD3<Float>]
    let scale: Float
    /// The closest accepted glyph to a collision-surface hit. This is approximate UI picking.
    func pick(at location:SIMD3<Float>, range:Range<Int>? = nil) -> PolynomialPoint? {
      guard (0..<3).allSatisfy({ location[$0].isFinite }) else { return nil }
      var nearest:Int?, distance = Float.infinity
      for index in range ?? glyphs.indices {
        guard glyphs.indices.contains(index) else { continue }
        let glyph = glyphs[index]
        guard glyph.opacity >= 0.06 else { continue }
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
    starSize:Double, colorLower:Bool, palette:String, normal:SIMD3<Double>?, keep:[Int], projection:Bool, catalogue:PolynomialCatalogueMetadata? = nil, sourceMorph:PolynomialSourceMorph.Settings? = nil) -> Snapshot? {
    guard radius > 0, points.count <= maximumPoints, starSize.isFinite, starSize > 0 else { return nil }
    let scale = Float(0.96/Double(radius))
    var glyphs:[Glyph] = []; glyphs.reserveCapacity(points.count)
    var batches:[UInt64:[Int]] = [:], alphas:[UInt64:Double] = [:], radial:[SIMD3<Float>] = []
    if projection { radial.reserveCapacity(points.count/3) }
    for p in points {
      let base = SIMD3(Double(p.xyz[0]),Double(p.xyz[1]),Double(p.xyz[2]))
      guard let shown = PolynomialMobius.mapDisplayCoordinates(rows:rows,base),
        (0..<3).allSatisfy({ shown[$0].isFinite }) else { return nil }
      let sourceBody = sourceMorph.map { PolynomialSourceMorph.body(point:p,shown:shown,settings:$0) }
      let position = (sourceBody?.position ?? SIMD3(Float(shown.x),Float(shown.y),Float(shown.z)))*scale
      let baseFactor = origin && p.delta < 0
        ? Float(0.4*pow(Double(-p.delta),0.25)/sqrt(max(0.000001,abs(shown.y))))
        : PolynomialAppearance.radiusFactor(p,colorLower:colorLower,atOrigin:false)
      let factor = sourceBody.map { max(0.000001,$0.radius*scale/0.0075) }
        ?? Float(starSize)*baseFactor*(p.necklace && p.kind == 2 && !origin ? 1.35:1)
      let fade = normal.map { PolynomialAppearance.focusFade(p,position:shown,normal:$0,radius:radius,keep:keep) } ?? 1
      guard (0..<3).allSatisfy({ position[$0].isFinite }), factor.isFinite, factor > 0 else { return nil }
      let opacity = sourceBody.map { Double($0.alpha) } ?? catalogueOpacity(point:p,shown:shown,catalogue:catalogue)
      let rgb = PolynomialAppearance.color(p,colorLower:colorLower,palette:palette)
      let rgbKey = sourceBody == nil ? colorKey(rgb*fade*opacity) : colorKey(rgb)
      var key=UInt64(rgbKey),materialAlpha=1.0
      if var settings=sourceMorph {
        // Stable 16-level endpoint bins keep entities/buffers reusable throughout a morph.
        // Only RealityKit material opacity is quantized; numerical source body outputs remain intact.
        settings.progress=0
        let start=Double(PolynomialSourceMorph.body(point:p,shown:shown,settings:settings).alpha)
        settings.progress=1
        let primitive=PolynomialPoint(abc:p.abc,xyz:p.xyz,delta:p.delta,kind:p.kind,divisor:1,onPlane:p.onPlane,necklace:p.necklace)
        let end=Double(PolynomialSourceMorph.body(point:primitive,shown:shown,settings:settings).alpha)
        let startBin=UInt64(max(0,min(15,(start*15).rounded()))),endBin=UInt64(max(0,min(15,(end*15).rounded())))
        let nonprimitive=p.kind == 2 && p.divisor != 1
        key |= startBin<<24 | endBin<<28 | (nonprimitive ? UInt64(1)<<32:0) | UInt64(1)<<33
        let progress=sourceMorph!.progress
        materialAlpha=(Double(startBin)+(Double(endBin)-Double(startBin))*progress)/15
        if nonprimitive { materialAlpha *= 1-progress }
      }
      // Crop-zero entries stay absent. Whole-zero and primitive-fading entries retain stable buffers.
      if sourceBody.map({$0.radius > 0}) ?? (opacity > 0) {
        batches[key,default:[]].append(glyphs.count); alphas[key]=materialAlpha
      }
      glyphs.append(Glyph(point:p,position:position,factor:factor,colorKey:rgbKey,opacity:opacity))
      if projection, sourceMorph == nil, opacity > 0, p.delta < 0, catalogue == nil || (p.kind == 2 && p.divisor == 1), abs(position.y) > 0.000001 {
        let projected = position*(4*scale/position.y)
        guard (0..<3).allSatisfy({ projected[$0].isFinite }) else { return nil }
        radial.append(projected)
      }
    }
    return Snapshot(glyphs:glyphs,batches:batches,materialAlpha:alphas,radialPositions:radial,scale:scale)
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
        guard glyph.opacity >= 0.06 else { continue }
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
