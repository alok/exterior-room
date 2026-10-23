// SPDX-License-Identifier: GPL-3.0-or-later
// Roots layout/picking adapted from FareyVision 2a0ef3216a931bdcf6cdd9ba89a1baf6f4cfa46a:
// Farey/Sources/RootsPaneView.swift SHA256 d2371bb8247bfbdf8ee9b6dd56360e09496c6a054fac302b99155fa07c7b13c4
// Pan/zoom/resize and label-edge behavior: Farey/WebXR/roots-pane.js
// SHA256 cbbbb4f0415d9cc534f5c0f4fd7287e5279c50bfb56581a1243fabb97ee1e87b
// Visualization after Katherine Stange / Harriss–Stange–Trettel.
// Alok Singh with OpenAI Codex, 2026-10-23: render accepted Lean data without generating a lattice locally.
import Foundation
import CoreGraphics

/// Approximate presentation only. Classification, coefficients and discriminants are supplied by Lean.
/// The caller supplies accepted rational action rows converted to Double, or explicitly marked preview rows.
enum PolynomialRootsGeometry {
  struct Viewport: Equatable, Sendable {
    let size: CGSize
    let center: SIMD2<Double>
    let scale: Double

    /// Canonical fitted view: real axis 28 points above the bottom, horizontal span 2.4.
    init?(size: CGSize) {
      guard Self.validSize(size) else { return nil }
      let scale = Double(size.width) / 2.4
      self.init(size: size, center: [0, (Double(size.height) / 2 - 28) / scale], scale: scale)
    }

    private init?(size: CGSize, center: SIMD2<Double>, scale: Double) {
      guard Self.validSize(size), center.x.isFinite, center.y.isFinite, scale.isFinite, scale > 0 else { return nil }
      self.size = size; self.center = center; self.scale = scale
    }

    var fitScale: Double { Double(size.width) / 2.4 }
    var zoom: Double { scale / fitScale }

    /// Includes the real axis and lower half-plane so axes and zoom anchors use the same transform.
    func screen(_ root: SIMD2<Double>) -> CGPoint? {
      guard root.x.isFinite, root.y.isFinite else { return nil }
      let x = Double(size.width) / 2 + (root.x - center.x) * scale
      let y = Double(size.height) / 2 - (root.y - center.y) * scale
      guard x.isFinite, y.isFinite else { return nil }
      return CGPoint(x: x, y: y)
    }

    /// Only valid upper-half-plane locations may anchor an action drag.
    func root(at point: CGPoint) -> SIMD2<Double>? {
      guard let root = coordinate(at: point), root.y > 1e-6 else { return nil }
      return root
    }

    /// Apply a cumulative screen translation to the viewport saved at gesture start.
    /// This moves only the picture; it never modifies the algebraic action.
    func panned(by translation: CGSize) -> Self? {
      guard translation.width.isFinite, translation.height.isFinite else { return nil }
      return Self(size: size,
        center: center + [-Double(translation.width) / scale, Double(translation.height) / scale], scale: scale)
    }

    /// Anchor-preserving zoom, bounded exactly as the browser to 0.5…8 times fitted scale.
    func zoomed(by factor: Double, at anchor: CGPoint) -> Self? {
      guard factor.isFinite, factor > 0 else { return nil }
      return zoomed(logFactor: log(factor), at: anchor)
    }

    func zoomed(wheelDelta: Double, at anchor: CGPoint) -> Self? {
      guard wheelDelta.isFinite else { return nil }
      return zoomed(logFactor: -wheelDelta * 0.0015, at: anchor)
    }

    /// Resizing keeps the chart center and scales with width, as in the canonical browser.
    func resized(to size: CGSize) -> Self? {
      guard Self.validSize(size) else { return nil }
      return Self(size: size, center: center, scale: scale * (Double(size.width) / Double(self.size.width)))
    }

    private func coordinate(at point: CGPoint) -> SIMD2<Double>? {
      guard point.x.isFinite, point.y.isFinite else { return nil }
      let root = center + [(Double(point.x) - Double(size.width) / 2) / scale,
        -(Double(point.y) - Double(size.height) / 2) / scale]
      return root.x.isFinite && root.y.isFinite ? root : nil
    }

    private func zoomed(logFactor: Double, at anchor: CGPoint) -> Self? {
      guard let root = coordinate(at: anchor), !logFactor.isNaN else { return nil }
      // Log arithmetic avoids an overflowing intermediate for an otherwise valid clamped zoom.
      let logZoom = min(log(8.0), max(log(0.5), log(zoom) + logFactor))
      let nextScale = fitScale * exp(logZoom)
      let nextCenter = root + [-(Double(anchor.x) - Double(size.width) / 2) / nextScale,
        (Double(anchor.y) - Double(size.height) / 2) / nextScale]
      return Self(size: size, center: nextCenter, scale: nextScale)
    }

    private static func validSize(_ size: CGSize) -> Bool {
      size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }
  }

  struct Dot: Equatable, Sendable {
    let point: PolynomialPoint
    let root: SIMD2<Double>
    let center: CGPoint
    /// Canonical radius before the minimum drawable footprint is applied.
    let radius: Double
    var drawnRadius: Double { max(radius, 0.6) }
    var opacity: Double { radius < 0.6 ? (radius / 0.6) * (radius / 0.6) : 1 }
    var isDrawable: Bool { radius > 0.08 }
    var ringRadius: Double { drawnRadius + 3 }
    /// Ordinary source viewer Xt uses its own minimum; canonical rings remain unchanged.
    var sourceRingRadius: Double { max(5,radius + 4) }
    var labelPosition: CGPoint {
      CGPoint(x: Double(center.x) + max(8, radius + 7), y: Double(center.y) + max(8, radius + 6))
    }

    /// The browser flips a measured label left near the right edge. Text measurement belongs to the renderer.
    func labelPosition(textWidth: Double, in viewport: Viewport) -> CGPoint? {
      guard textWidth.isFinite, textWidth >= 0 else { return nil }
      let offset = max(8, radius + 7)
      let x = Double(center.x) + offset + textWidth > Double(viewport.size.width) - 4
        ? Double(center.x) - offset - textWidth : Double(center.x) + offset
      return CGPoint(x: x, y: Double(labelPosition.y))
    }

    /// Optional browser-style viewport culling; retaining every dot matches the native source.
    func intersects(_ viewport: Viewport) -> Bool {
      Double(center.x) >= -radius && Double(center.x) <= Double(viewport.size.width) + radius
        && Double(center.y) >= -radius && Double(center.y) <= Double(viewport.size.height) + radius
    }
  }

  /// Ascending radius order puts larger, usually primitive, representatives on top of coincident multiples.
  static func dots(points: [PolynomialPoint], rows: [Double], viewport: Viewport, sigma: Double = 1,
    preservingSourceOrder:Bool = false) -> [Dot] {
    guard rows.count == 9, rows.allSatisfy(\.isFinite), sigma.isFinite, sigma > 0 else { return [] }
    let radiusScale = 0.03 * sigma * viewport.scale
    guard radiusScale.isFinite, radiusScale > 0 else { return [] }
    var result: [(index: Int, dot: Dot)] = []
    for (index, point) in points.enumerated() {
      guard point.abc.count == 3, point.kind == 2, point.abc[0] > 0, point.delta < 0,
        let image = PolynomialMobius.applyRows(rows, [Double(point.abc[0]), Double(point.abc[1]), Double(point.abc[2])]),
        image.x > 0 else { continue }
      let denominator = 2 * image.x
      guard denominator.isFinite else { continue }
      // Negating after conversion also avoids overflowing if an unvalidated test input contains Int.min.
      let root = SIMD2(-image.y / denominator, sqrt(-Double(point.delta)) / denominator)
      let radius = radiusScale / image.x
      guard radius.isFinite, radius > 0, let center = viewport.screen(root), root.y > 0 else { continue }
      result.append((index, Dot(point: point, root: root, center: center, radius: radius)))
    }
    if preservingSourceOrder { return result.map(\.dot) }
    return result.sorted {
      $0.dot.radius == $1.dot.radius ? $0.index < $1.index : $0.dot.radius < $1.dot.radius
    }.map(\.dot)
  }

  /// Source viewer Jt/Xt (SHA256 f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b).
  /// An inspection supplies the signed identity, primitive representative and discriminant.
  /// Only the approximate root/radius use the positive primitive representative. The returned
  /// point keeps the original signed identity; it is a visual ring, never an added pick target.
  /// No catalogue, crop, body opacity or primitive-body filter applies to these selected rings.
  static func sourceSelectionRing(inspection detail:PolynomialInspection,rows:[Double],
    viewport:Viewport,sigma:Double = 1) -> Dot? {
    guard detail.isValid, ["upper","lower"].contains(detail.kind), detail.primitive[0] > 0 else { return nil }
    let divisorSquared = detail.divisor * detail.divisor
    guard detail.delta % divisorSquared == 0 else { return nil }
    let abc = detail.primitive
    let visual = PolynomialPoint(abc:abc,xyz:[-abc[1],abc[0]+abc[2],abc[2]-abc[0]],
      delta:detail.delta/divisorSquared,kind:2,divisor:1,onPlane:false,necklace:false)
    guard let dot = dots(points:[visual],rows:rows,viewport:viewport,sigma:sigma).first else { return nil }
    let identity = PolynomialPoint(abc:detail.point,xyz:detail.xyz,delta:detail.delta,
      kind:detail.kind == "lower" ? 3:2,divisor:detail.divisor,onPlane:false,necklace:false)
    return Dot(point:identity,root:dot.root,center:dot.center,radius:dot.radius)
  }

  /// Source 2D body alpha: crop × (no plane/on plane ? 1 : .26 in the dark theme),
  /// followed by the ordinary tiny-dot footprint attenuation. This is not Euclidean plane fade.
  static func sourceBodyOpacity(_ dot:Dot,crop:Double,hasPlane:Bool) -> Double {
    dot.opacity * sourceBodyAlpha(dot.point,crop:crop,hasPlane:hasPlane)
  }
  static func sourceBodyAlpha(_ point:PolynomialPoint,crop:Double,hasPlane:Bool) -> Double {
    guard crop.isFinite else { return 0 }
    return max(0,min(1,crop)) * (hasPlane && !point.onPlane ? 0.26:1)
  }

  /// Source bn: pre-raster packed alpha gate, expanded hit radius, then radius-biased score.
  /// The caller preserves catalogue order; exact score ties retain its first signed identity.
  /// Body footprint attenuation is deliberately absent from this picking gate.
  static func pickSource(_ dots:[Dot],at location:CGPoint,hasPlane:Bool,crop:(Dot)->Double) -> Dot? {
    guard location.x.isFinite, location.y.isFinite else { return nil }
    var best:Dot?, bestScore = Double.infinity
    for dot in dots {
      guard dot.radius.isFinite, dot.radius > 0, dot.center.x.isFinite, dot.center.y.isFinite,
        Double(Float(sourceBodyAlpha(dot.point,crop:crop(dot),hasPlane:hasPlane))) >= 0.05 else { continue }
      let distance = hypot(Double(dot.center.x-location.x),Double(dot.center.y-location.y))
      guard distance <= max(7,dot.radius+4) else { continue }
      let score = distance - 0.8*min(dot.radius,12)
      if score < bestScore { best = dot; bestScore = score }
    }
    return best
  }

  /// Renderer-only upper-half-plane geodesic through two already transformed real endpoints.
  /// A finite pair produces 65 semicircle samples from its smaller endpoint to its larger endpoint.
  /// Either sign of infinity denotes the same projective endpoint and produces a vertical segment.
  static func geodesic(endpoints: [Double], viewport: Viewport) -> [CGPoint] {
    guard endpoints.count == 2, endpoints.allSatisfy({ !$0.isNaN }) else { return [] }
    let finite = endpoints.filter(\.isFinite)
    if finite.count == 1 {
      guard let axis = viewport.screen([finite[0], 0]) else { return [] }
      return [axis, CGPoint(x: axis.x, y: 0)]
    }
    guard finite.count == 2 else { return [] }
    let lower = min(finite[0], finite[1]), upper = max(finite[0], finite[1])
    guard lower < upper else { return [] }
    // Halving first avoids overflowing the sum/difference for widely separated finite endpoints.
    let center = lower / 2 + upper / 2, radius = upper / 2 - lower / 2
    guard center.isFinite, radius.isFinite, radius > 0 else { return [] }
    var path: [CGPoint] = []
    for index in 0...64 {
      let root: SIMD2<Double>
      switch index {
      case 0: root = [lower, 0]
      case 32: root = [center, radius]
      case 64: root = [upper, 0]
      default:
        let angle = Double.pi * Double(64 - index) / 64
        root = [center + radius * cos(angle), radius * sin(angle)]
      }
      guard let point = viewport.screen(root) else { return [] }
      path.append(point)
    }
    return path
  }

  /// Native/browser rule: nearest within max(7 points, radius), then largest within a 0.5-point tie.
  /// Tiny dots remain pickable as in the canonical source; isDrawable controls painting only.
  static func pick(_ dots: [Dot], at location: CGPoint) -> Dot? {
    guard location.x.isFinite, location.y.isFinite else { return nil }
    let near = dots.compactMap { dot -> (dot: Dot, distance: Double)? in
      guard dot.radius.isFinite, dot.radius > 0, dot.center.x.isFinite, dot.center.y.isFinite else { return nil }
      let distance = hypot(Double(dot.center.x - location.x), Double(dot.center.y - location.y))
      return distance <= max(7, dot.radius) ? (dot, distance) : nil
    }
    guard let nearest = near.map(\.distance).min() else { return nil }
    var best: Dot?
    for candidate in near where candidate.distance <= nearest + 0.5 {
      if let previous = best {
        if candidate.dot.radius > previous.radius { best = candidate.dot }
      } else { best = candidate.dot }
    }
    return best
  }
}
