// SPDX-License-Identifier: GPL-3.0-or-later
// Origin shell adapted read-only from Farey/Sources/StarscapeRenderer+Sky.swift,
// SHA256 94ef5147c665551fffbf0e6d8e9015e9e85900c2c9528fa5ed4d7ddb1907e13f
// (canonical HEAD 11d58f12f9dba6ea421c3e0fbb90b4f92471f09d, 2026-10-23).
// Input mapping and mesh geometry are approximate UI operations, not Lean proofs.
import Foundation
import simd

enum PolynomialSpatialInput {
  /// Explicit world placement used by the renderer. The local cone origin is the sampled device origin;
  /// the existing upper/lower nappe rotation is applied in that device frame, not around world zero.
  static func originPlacement(devicePose:simd_float4x4,lower:Bool) -> simd_float4x4 {
    devicePose * simd_float4x4(simd_quatf(angle:lower ? .pi/2:-.pi/2,axis:[1,0,0]))
  }
  static func upperPoint(direction:SIMD3<Double>) -> SIMD2<Double>? {
    guard (0..<3).allSatisfy({direction[$0].isFinite}),abs(direction.y)>1e-8 else { return nil }
    return PolynomialMobius.kleinToUpper([direction.x/direction.y,direction.z/direction.y])
  }
  static let shellRadius:Float = 2.4
  static func shell(bands:Int = 12,sectors:Int = 24) -> (positions:[SIMD3<Float>],indices:[UInt16]) {
    guard bands>=2,sectors>=3,(bands+1)*(sectors+1) <= Int(UInt16.max) else { return ([],[]) }
    var positions:[SIMD3<Float>]=[],faces:[UInt16]=[]
    for band in 0...bands {
      let polar=Float.pi*Float(band)/Float(bands)
      for sector in 0...sectors {
        let azimuth=2*Float.pi*Float(sector)/Float(sectors)
        positions.append(shellRadius*SIMD3(sin(polar)*cos(azimuth),cos(polar),sin(polar)*sin(azimuth)))
      }
    }
    for band in 0..<bands { for sector in 0..<sectors {
      let a=UInt16(band*(sectors+1)+sector),b=a+UInt16(sectors+1)
      faces += [a,b,a+1,a+1,b,b+1]
    }}
    return (positions,faces)
  }
  static let shellInradius:Float = {
    let mesh=shell()
    return stride(from:0,to:mesh.indices.count,by:3).compactMap { i -> Float? in
      let a=mesh.positions[Int(mesh.indices[i])],b=mesh.positions[Int(mesh.indices[i+1])],c=mesh.positions[Int(mesh.indices[i+2])]
      let u=b-a,v=c-a,n=SIMD3(u.y*v.z-u.z*v.y,u.z*v.x-u.x*v.z,u.x*v.y-u.y*v.x)
      let length=sqrt(n.x*n.x+n.y*n.y+n.z*n.z)
      guard length>1e-6 else { return nil }
      return abs((n.x*a.x+n.y*a.y+n.z*a.z)/length)
    }.min() ?? 0
  }()
  static func shellScale(reach:Float) -> Float { max(1,(reach+0.1)/shellInradius) }
}
