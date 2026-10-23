// SPDX-License-Identifier: GPL-3.0-or-later
// Renderer-only port of Katherine Stange's ordinary source viewer an/ht/Nt/$t.
// Source SHA f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b.
// Exact identities/action receipts still come from Lean; these are display approximations.
import Foundation

enum PolynomialSourceMorph {
  struct Settings: Sendable {
    var depth:Int
    var heightFraction = 0.6
    var progress = 0.0
    var eye = 0.0
    var sigma = 1.0
    var whole = true
    var dust = false
    var screen = true
    var light = false
    var hasPlane = false
    var height:Double { heightFraction*Double(depth) }
    var otherRadius:Int { whole ? Int((0.4*Double(depth)).rounded()) : dust ? 10 : 0 }
  }
  struct Body:Sendable {
    let position:SIMD3<Float>, radius:Float, alpha:Float
    var pickable:Bool { alpha >= 0.06 }
  }
  /// Display classification from already validated exact identities/plane; not a new Lean claim.
  /// Bounds make each product < 8,589,934,592 and their sum safely representable by Int64.
  static func incident(_ abc:[Int],normal:[Int]?) -> Bool {
    guard abc.count == 3,abc.allSatisfy({(-PolynomialIdentityBounds.coordinate...PolynomialIdentityBounds.coordinate).contains($0)}),
      let normal,normal.count == 3,normal.allSatisfy({(-PolynomialIdentityBounds.normal...PolynomialIdentityBounds.normal).contains($0)}) else { return false }
    return -2*normal[2]*abc[0]+normal[1]*abc[1]-2*normal[0]*abc[2] == 0
  }
  /// Approximate source guide clipping in the displayed basis; no coefficient identity changes.
  static func clipPlaneVertex(_ point:SIMD3<Double>,radius:Double) -> SIMD3<Double>? {
    guard radius > 0,radius.isFinite,(0..<3).allSatisfy({point[$0].isFinite}) else { return nil }
    let norm=hypot(hypot(point.x,point.y),point.z)
    let bound=max(1,hypot(point.x,point.z)/radius,point.y/(point.y >= 0 ? radius:-0.3*radius),norm/(1.5*radius))
    return point/bound
  }
  static func ease(_ t:Double) -> Double {
    let t = max(0,min(1,t)); return t < 0.5 ? 4*t*t*t : 1-pow(-2*t+2,3)/2
  }
  static func crop(_ distance:Double,_ cutoff:Double) -> Double {
    let inner = 0.86*cutoff
    if distance <= inner { return 1 }; if distance >= cutoff { return 0 }
    let t = (distance-inner)/(cutoff-inner); return 1-t*t*(3-2*t)
  }
  static func markerPosition(_ shown:SIMD3<Double>,upper:Bool,settings s:Settings) -> SIMD3<Float> {
    let factor = upper && shown.y > 0 ? 1-s.progress+s.progress*s.height/shown.y : 1
    return SIMD3(Float(shown.x*factor),Float(shown.y*factor),Float(shown.z*factor))
  }
  static func body(point p:PolynomialPoint,shown:SIMD3<Double>,settings s:Settings) -> Body {
    let y = shown.y, norm = hypot(hypot(shown.x,shown.y),shown.z)
    let cropFade = Double(Float(crop(p.kind == 2 ? y:norm,Double(p.kind == 2 ? s.depth:s.otherRadius))))
    guard cropFade > 0 else { return Body(position:.zero,radius:0,alpha:0) }
    let eye = s.eye, progress = s.progress, whole = s.whole ? 1.0:0.0
    let themeAlpha = s.light ? 0.36:0.45
    var radius:Double, alpha:Double
    if p.kind == 2 {
      let fourthRoot = Double(Float(pow(Double(-p.delta),0.25)))
      let angular = 0.06*s.sigma*fourthRoot/(y*sqrt(y))
      let lattice = 0.15*s.sigma*(p.divisor == 1 ? 1:0.72)
      let initialRadius = lattice+(angular*y-lattice)*eye
      let emphasis = !s.hasPlane ? 1.0 : p.onPlane ? 2.0 : s.light ? 0.32:0.26
      var initialAlpha = emphasis >= 1 ? themeAlpha+(0.95-themeAlpha)*eye : emphasis
      initialAlpha *= 1-whole*(1-crop(Double(Float(norm)),Double(Int((0.4*Double(s.depth)).rounded()))))
      let screenWeight = s.screen ? 1-eye:0
      if screenWeight > 0.001 {
        let clipped = max(0,min(1,(y-s.height)/3+0.5))
        initialAlpha *= 1-0.75*screenWeight*clipped*(1-eye)
      }
      let finalAlpha = emphasis >= 1 ? 0.95:emphasis
      radius = initialRadius+(angular*s.height-initialRadius)*progress
      alpha = cropFade*(initialAlpha+(finalAlpha-initialAlpha)*progress)
      if p.divisor != 1 { alpha *= 1-progress }
      if emphasis > 1 { radius *= 1+0.35*(1-eye)*(1-progress) }
    } else {
      let initialRadius = p.kind == 0 ? 0.09:0.075
      let eyeRadius = initialRadius+(0.01*abs(y)+0.004-initialRadius)*eye
      let dustAlpha = s.dust ? (s.light ? 0.5:0.42)*(p.kind == 0 ? 1.5:p.kind == 1 ? 1:0.8)*(1-0.6*eye):0
      let wholeAlpha = themeAlpha*(1-eye)
      radius = eyeRadius+(0.15*s.sigma-eyeRadius)*whole
      alpha = cropFade*(dustAlpha+(wholeAlpha-dustAlpha)*whole)
      if s.hasPlane && p.onPlane { radius = 0.12; alpha = cropFade*0.9 }
    }
    return Body(position:markerPosition(shown,upper:p.kind == 2,settings:s),radius:Float(radius),alpha:Float(min(1,alpha)))
  }
}
