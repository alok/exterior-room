// SPDX-License-Identifier: GPL-3.0-or-later
// Alok Singh with OpenAI Codex, 2026-10-23.
// Pure renderer geometry tests using actual Lean exports; no UI gesture or kernel-checking claim.
import Foundation
import XCTest
@testable import ExteriorRoomCore

final class PolynomialRootsGeometryTests: XCTestCase {
  private typealias Geometry = PolynomialRootsGeometry
  private let identityRows: [Double] = [1,0,0,0,1,0,0,0,1]

  func testCanonicalFitProjectsActualLeanUnitAndDefaultRoots() throws {
    let viewport = try fitted(), points = try cloud()
    let dots = Geometry.dots(points: points, rows: identityRows, viewport: viewport)
    let unit = try XCTUnwrap(dots.first { $0.point.abc == [1,0,1] })
    let selected = try XCTUnwrap(dots.first { $0.point.abc == [1,-1,2] })
    XCTAssertEqual(viewport.scale, 560 / 2.4, accuracy: 1e-12)
    close(try XCTUnwrap(viewport.screen([0,0])), CGPoint(x: 280, y: 532))
    close(unit.root, [0,1])
    close(unit.center, CGPoint(x: 280, y: 532 - 560 / 2.4))
    XCTAssertEqual(unit.radius, 7, accuracy: 1e-12)
    close(selected.root, [0.5, sqrt(7) / 2])
    close(selected.center, CGPoint(x: 280 + 0.5 * viewport.scale, y: 532 - sqrt(7) / 2 * viewport.scale))
    XCTAssertEqual(selected.point, try XCTUnwrap(points.first { $0.abc == [1,-1,2] }))
    XCTAssertEqual(dots.count, points.filter { $0.kind == 2 }.count)
    XCTAssertTrue(dots.allSatisfy { $0.point.abc[0] > 0 && $0.point.kind == 2 })
    XCTAssertFalse(dots.contains { $0.point.abc == [-1,0,-1] || $0.point.kind == 0 || $0.point.kind == 1 })
  }

  func testAcceptedLeanRationalRowsMoveRootsWithoutRelabelingBasePoints() throws {
    let viewport = try fitted(), points = try cloud(), action = try rationalAction()
    let rows = try XCTUnwrap(action.coefficientRowsApprox)
    let dots = Geometry.dots(points: points, rows: rows, viewport: viewport)
    let unit = try XCTUnwrap(dots.first { $0.point.abc == [1,0,1] })
    let selected = try XCTUnwrap(dots.first { $0.point.abc == [1,-1,2] })
    // Independent checkpoint: J([3,1;1,2])/5 sends the unit form to (1,-2,2).
    close(unit.root, [1,1])
    XCTAssertEqual(unit.radius, 7, accuracy: 1e-12)
    // The default form's actual Lean receipt is (8,-23,22)/5 with discriminant -7.
    XCTAssertEqual(action.imageNumerator, [8,-23,22]); XCTAssertEqual(action.denominator, 5)
    close(selected.root, [23.0 / 16, 5 * sqrt(7) / 16])
    XCTAssertEqual(selected.radius, 35.0 / 8, accuracy: 1e-12)
    XCTAssertEqual(selected.point.abc, [1,-1,2]); XCTAssertEqual(selected.point.delta, -7)
    XCTAssertFalse(selected.intersects(viewport), "Native geometry retains offscreen roots; the renderer may cull them")
    XCTAssertTrue(unit.intersects(viewport))
  }

  func testCoincidentActualLeanMultiplesDrawSmallFirstAndPickLargest() throws {
    let viewport = try fitted(), points = try cloud()
    let pair = points.filter { $0.abc == [1,0,1] || $0.abc == [2,0,2] }
    XCTAssertEqual(pair.count, 2)
    let dots = Geometry.dots(points: pair, rows: identityRows, viewport: viewport)
    XCTAssertEqual(dots.map(\.point.abc), [[2,0,2], [1,0,1]])
    close(dots[0].center, dots[1].center)
    XCTAssertEqual(dots[0].radius, 3.5, accuracy: 1e-12)
    XCTAssertEqual(dots[1].radius, 7, accuracy: 1e-12)
    XCTAssertEqual(Geometry.pick(dots, at: dots[0].center)?.point.abc, [1,0,1])
    XCTAssertEqual(Geometry.pick(Array(dots.reversed()), at: dots[0].center)?.point.abc, [1,0,1])
  }

  func testPickingUsesSevenPointThresholdHalfPointTieAndLargestFootprint() throws {
    let point = try unit()
    let small = dot(point, x: 0, y: 0, radius: 1)
    let largerTie = dot(point, x: 0.5, y: 0, radius: 3)
    let largerOutsideTie = dot(point, x: 0.50001, y: 0, radius: 4)
    XCTAssertEqual(Geometry.pick([small, largerTie, largerOutsideTie], at: .zero), largerTie)
    XCTAssertEqual(Geometry.pick([largerOutsideTie, small], at: .zero), small)
    XCTAssertEqual(Geometry.pick([small], at: CGPoint(x: 7, y: 0)), small)
    XCTAssertNil(Geometry.pick([small], at: CGPoint(x: 7.00001, y: 0)))
    let large = dot(point, x: 20, y: 0, radius: 20)
    XCTAssertEqual(Geometry.pick([large], at: .zero), large)
    XCTAssertNil(Geometry.pick([large], at: CGPoint(x: -0.00001, y: 0)))
    let equallyLarge = dot(point, x: -0.5, y: 0, radius: 3)
    XCTAssertEqual(Geometry.pick([largerTie, equallyLarge], at: .zero), largerTie,
      "Equal-radius ties retain the first source-ordered candidate")
    XCTAssertNil(Geometry.pick([small], at: CGPoint(x: CGFloat.nan, y: 0)))
    XCTAssertNil(Geometry.pick([], at: .zero))
  }

  func testCanonicalFootprintOpacityRingsAndLabelPlacement() throws {
    let point = try unit(), viewport = try fitted()
    let tiny = dot(point, x: 20, y: 30, radius: 0.3)
    XCTAssertEqual(tiny.drawnRadius, 0.6)
    XCTAssertEqual(tiny.opacity, 0.25, accuracy: 1e-12)
    XCTAssertEqual(tiny.ringRadius, 3.6, accuracy: 1e-12)
    XCTAssertTrue(tiny.isDrawable)
    close(tiny.labelPosition, CGPoint(x: 28, y: 38))
    let cutoff = dot(point, x: 0, y: 0, radius: 0.08)
    XCTAssertFalse(cutoff.isDrawable)
    XCTAssertTrue(dot(point, x: 0, y: 0, radius: 0.080001).isDrawable)
    XCTAssertEqual(Geometry.pick([cutoff], at: .zero), cutoff, "Painting cutoff is not a picking cutoff in the source")
    let edge = dot(point, x: 530, y: 100, radius: 7)
    close(try XCTUnwrap(edge.labelPosition(textWidth: 40, in: viewport)), CGPoint(x: 476, y: 113))
    close(try XCTUnwrap(tiny.labelPosition(textWidth: 40, in: viewport)), CGPoint(x: 28, y: 38))
    XCTAssertNil(edge.labelPosition(textWidth: -.infinity, in: viewport))
    XCTAssertTrue(dot(point, x: -7, y: 100, radius: 7).intersects(viewport))
    XCTAssertFalse(dot(point, x: -7.00001, y: 100, radius: 7).intersects(viewport))
  }

  func testPanMovesThePictureAndKeepsScreenRootInverse() throws {
    let viewport = try fitted(), root = SIMD2<Double>(0.4, 1.3)
    let before = try XCTUnwrap(viewport.screen(root))
    let moved = try XCTUnwrap(viewport.panned(by: CGSize(width: 35, height: -50)))
    let after = try XCTUnwrap(moved.screen(root))
    close(after, CGPoint(x: before.x + 35, y: before.y - 50))
    close(try XCTUnwrap(moved.root(at: after)), root)
    XCTAssertEqual(moved.scale, viewport.scale)
    let restored = try XCTUnwrap(moved.panned(by: CGSize(width: -35, height: 50)))
    close(restored.center, viewport.center)
    close(try XCTUnwrap(restored.screen(root)), before)
  }

  func testZoomPreservesItsAnchorAndScalesRootDistanceAndDotRadius() throws {
    let viewport = try fitted(), root = SIMD2<Double>(0.25, 1.1)
    let anchor = try XCTUnwrap(viewport.screen(root))
    let enlarged = try XCTUnwrap(viewport.zoomed(by: 2, at: anchor))
    close(try XCTUnwrap(enlarged.screen(root)), anchor)
    close(try XCTUnwrap(enlarged.root(at: anchor)), root)
    XCTAssertEqual(enlarged.scale, viewport.scale * 2, accuracy: 1e-12)
    let neighbor = root + SIMD2<Double>(0.2, 0.3)
    let before = try XCTUnwrap(viewport.screen(neighbor)), after = try XCTUnwrap(enlarged.screen(neighbor))
    close(after, CGPoint(x: anchor.x + 2 * (before.x - anchor.x), y: anchor.y + 2 * (before.y - anchor.y)))
    let point = try unit()
    let originalDot = try XCTUnwrap(Geometry.dots(points: [point], rows: identityRows, viewport: viewport).first)
    let enlargedDot = try XCTUnwrap(Geometry.dots(points: [point], rows: identityRows, viewport: enlarged).first)
    XCTAssertEqual(enlargedDot.radius, originalDot.radius * 2, accuracy: 1e-12)
    XCTAssertEqual(enlargedDot.point, originalDot.point)
  }

  func testWheelZoomClampsAndCanAnchorBelowTheRealAxis() throws {
    let viewport = try fitted(), anchorRoot = SIMD2<Double>(0.3, -0.2)
    let anchor = try XCTUnwrap(viewport.screen(anchorRoot))
    XCTAssertNil(viewport.root(at: anchor), "Below-axis points cannot begin an action drag")
    let wheel = try XCTUnwrap(viewport.zoomed(wheelDelta: 80, at: anchor))
    XCTAssertEqual(wheel.zoom, exp(-80 * 0.0015), accuracy: 1e-12)
    close(try XCTUnwrap(wheel.screen(anchorRoot)), anchor)
    let maximum = try XCTUnwrap(viewport.zoomed(by: Double.greatestFiniteMagnitude, at: anchor))
    let minimum = try XCTUnwrap(viewport.zoomed(by: Double.leastNonzeroMagnitude, at: anchor))
    XCTAssertEqual(maximum.zoom, 8, accuracy: 1e-12)
    XCTAssertEqual(minimum.zoom, 0.5, accuracy: 1e-12)
    close(try XCTUnwrap(maximum.screen(anchorRoot)), anchor)
    close(try XCTUnwrap(minimum.screen(anchorRoot)), anchor)
    let extremeWheel = try XCTUnwrap(viewport.zoomed(wheelDelta: -Double.greatestFiniteMagnitude, at: anchor))
    XCTAssertEqual(extremeWheel.zoom, 8, accuracy: 1e-12)
  }

  func testResizePreservesPanAndZoomAndRescalesWithWidth() throws {
    let base = try fitted()
    let panned = try XCTUnwrap(base.panned(by: CGSize(width: 80, height: 25)))
    let view = try XCTUnwrap(panned.zoomed(by: 3, at: CGPoint(x: 180, y: 210)))
    let resized = try XCTUnwrap(view.resized(to: CGSize(width: 1120, height: 1120)))
    XCTAssertEqual(resized.center, view.center)
    XCTAssertEqual(resized.zoom, view.zoom, accuracy: 1e-12)
    XCTAssertEqual(resized.scale, view.scale * 2, accuracy: 1e-12)
    let root = SIMD2<Double>(0.2, 0.9)
    let before = try XCTUnwrap(view.screen(root)), after = try XCTUnwrap(resized.screen(root))
    close(after, CGPoint(x: before.x * 2, y: before.y * 2))
    close(try XCTUnwrap(resized.root(at: after)), root)
  }

  func testActualLeanPairEndpointsProduceTheUnitGeodesic() throws {
    let viewport = try fitted(), plane = try pairedPlane()
    XCTAssertEqual(plane.endpoints.map(\.displayValue), [-1,1])
    let path = Geometry.geodesic(endpoints: plane.endpoints.map(\.displayValue), viewport: viewport)
    XCTAssertEqual(path.count, 65)
    guard path.count == 65 else { return }
    close(path[0], try XCTUnwrap(viewport.screen([-1,0])))
    close(path[32], try XCTUnwrap(viewport.screen([0,1])))
    close(path[64], try XCTUnwrap(viewport.screen([1,0])))
    for screen in path.dropFirst().dropLast() {
      let root = try XCTUnwrap(viewport.root(at: screen))
      XCTAssertEqual(root.x * root.x + root.y * root.y, 1, accuracy: 1e-12)
      XCTAssertGreaterThan(root.y, 0)
    }
    let reversed = Geometry.geodesic(endpoints: [1,-1], viewport: viewport)
    XCTAssertEqual(reversed.count, path.count)
    for (a,b) in zip(path,reversed) { close(a,b) }
  }

  func testActualD5ActionEndpointsProduceTheTranslatedAndResizedGeodesic() throws {
    let viewport = try fitted(), plane = try pairedPlane(), action = try rationalAction()
    let matrix = action.matrix.map(Double.init)
    let transformed = try plane.endpoints.map { endpoint in
      try XCTUnwrap(PolynomialMobius.actReal(matrix, endpoint.displayValue))
    }
    XCTAssertEqual(transformed[0], -2, accuracy: 1e-12)
    XCTAssertEqual(transformed[1], 4.0 / 3, accuracy: 1e-12)
    let path = Geometry.geodesic(endpoints: transformed, viewport: viewport)
    XCTAssertEqual(path.count, 65)
    guard path.count == 65 else { return }
    close(path[0], try XCTUnwrap(viewport.screen([-2,0])))
    close(path[32], try XCTUnwrap(viewport.screen([-1.0 / 3,5.0 / 3])))
    close(path[64], try XCTUnwrap(viewport.screen([4.0 / 3,0])))
    for screen in path.dropFirst().dropLast() {
      let root = try XCTUnwrap(viewport.root(at: screen))
      XCTAssertEqual(pow(root.x + 1.0 / 3,2) + root.y * root.y, 25.0 / 9, accuracy: 1e-11)
    }
    // The selected unit form is a member of the base pair's plane; its transformed root 1+i
    // lies on this circle, independently of how the display samples it.
    let unitDot = try XCTUnwrap(Geometry.dots(points: [try unit()],
      rows: try XCTUnwrap(action.coefficientRowsApprox), viewport: viewport).first)
    XCTAssertEqual(pow(unitDot.root.x + 1.0 / 3,2) + unitDot.root.y * unitDot.root.y, 25.0 / 9, accuracy: 1e-12)
  }

  func testVerticalGeodesicUsesTheFiniteEndpointAndCurrentViewport() throws {
    let viewport = try fitted()
    for endpoints in [[0.0, Double.infinity], [Double.infinity,0], [0,-Double.infinity]] {
      let path = Geometry.geodesic(endpoints: endpoints, viewport: viewport)
      XCTAssertEqual(path.count, 2)
      guard path.count == 2 else { continue }
      close(path[0], CGPoint(x: 280,y: 532)); close(path[1], CGPoint(x: 280,y: 0))
    }
    let moved = try XCTUnwrap(viewport.panned(by: CGSize(width: 40,height: -20)))
    let zoomed = try XCTUnwrap(moved.zoomed(by: 2,at: CGPoint(x: 180,y: 200)))
    let path = Geometry.geodesic(endpoints: [1,.infinity], viewport: zoomed)
    XCTAssertEqual(path.count, 2)
    guard path.count == 2 else { return }
    close(path[0], try XCTUnwrap(zoomed.screen([1,0])))
    close(path[1], CGPoint(x: path[0].x,y: 0))
  }

  func testGeodesicRejectsMissingCoincidentOrInvalidEndpoints() throws {
    let viewport = try fitted()
    let invalid: [[Double]] = [[], [1], [1,2,3], [2,2], [.infinity,.infinity],
      [-.infinity,.infinity], [.nan,0], [0,.nan], [Double.greatestFiniteMagnitude,.infinity]]
    for endpoints in invalid {
      XCTAssertTrue(Geometry.geodesic(endpoints: endpoints,viewport: viewport).isEmpty, "\(endpoints)")
    }
  }

  func testInvalidViewAndActionInputsFailWithoutInventingGeometry() throws {
    XCTAssertNil(Geometry.Viewport(size: .zero))
    XCTAssertNil(Geometry.Viewport(size: CGSize(width: -1, height: 560)))
    XCTAssertNil(Geometry.Viewport(size: CGSize(width: CGFloat.infinity, height: 560)))
    let viewport = try fitted(), point = try unit()
    XCTAssertNil(viewport.screen([.nan, 1]))
    XCTAssertNil(viewport.root(at: try XCTUnwrap(viewport.screen([0,0]))))
    XCTAssertNil(viewport.root(at: try XCTUnwrap(viewport.screen([0,0.0000001]))))
    XCTAssertNil(viewport.panned(by: CGSize(width: CGFloat.infinity, height: 0)))
    XCTAssertNil(viewport.resized(to: .zero))
    for factor in [0, -1, Double.nan, Double.infinity] {
      XCTAssertNil(viewport.zoomed(by: factor, at: .zero))
    }
    XCTAssertNil(viewport.zoomed(wheelDelta: .infinity, at: .zero))
    XCTAssertNil(viewport.zoomed(by: 2, at: CGPoint(x: CGFloat.nan, y: 0)))
    XCTAssertTrue(Geometry.dots(points: [point], rows: [], viewport: viewport).isEmpty)
    XCTAssertTrue(Geometry.dots(points: [point], rows: Array(repeating: .nan, count: 9), viewport: viewport).isEmpty)
    XCTAssertTrue(Geometry.dots(points: [point], rows: identityRows.map { -$0 }, viewport: viewport).isEmpty)
    XCTAssertTrue(Geometry.dots(points: [point], rows: identityRows, viewport: viewport, sigma: 0).isEmpty)
    XCTAssertTrue(Geometry.dots(points: [point], rows: identityRows, viewport: viewport, sigma: .infinity).isEmpty)
  }

  private func fitted() throws -> Geometry.Viewport {
    try XCTUnwrap(Geometry.Viewport(size: CGSize(width: 560, height: 560)))
  }
  private func cloud() throws -> [PolynomialPoint] {
    let data = try resource("polynomial-cloud-r6.json")
    let header = try JSONDecoder().decode(PolynomialHeader.self, from: data)
    let cloud = try JSONDecoder().decode(PolynomialCloud.self, from: data)
    XCTAssertTrue(header.recognized && header.ok); XCTAssertTrue(cloud.isValid)
    return cloud.points
  }
  private func unit() throws -> PolynomialPoint {
    try XCTUnwrap(cloud().first { $0.abc == [1,0,1] })
  }
  private func rationalAction() throws -> PolynomialAction {
    struct Fixtures: Decodable {
      struct Item: Decodable { let name: String; let response: PolynomialAction }
      let cases: [Item]
    }
    let items = try JSONDecoder().decode(Fixtures.self, from: resource("polynomial-action-cases.json")).cases
    let action = try XCTUnwrap(items.first { $0.name == "rational/default" }?.response)
    XCTAssertTrue(action.isValid)
    return action
  }
  private func pairedPlane() throws -> PolynomialPlane {
    struct Fixtures: Decodable { let pair: PolynomialPlane }
    let plane = try JSONDecoder().decode(Fixtures.self,from: resource("polynomial-test-cases.json")).pair
    XCTAssertTrue(plane.isValidPair)
    return plane
  }
  private func resource(_ name: String) throws -> Data {
    let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try Data(contentsOf: native.appendingPathComponent("Resources/\(name)"))
  }
  private func dot(_ point: PolynomialPoint, x: Double, y: Double, radius: Double) -> Geometry.Dot {
    Geometry.Dot(point: point, root: [0,1], center: CGPoint(x: x, y: y), radius: radius)
  }
  private func close(_ actual: CGPoint, _ expected: CGPoint, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(actual.x, expected.x, accuracy: 1e-10, file: file, line: line)
    XCTAssertEqual(actual.y, expected.y, accuracy: 1e-10, file: file, line: line)
  }
  private func close(_ actual: SIMD2<Double>, _ expected: SIMD2<Double>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(actual.x, expected.x, accuracy: 1e-12, file: file, line: line)
    XCTAssertEqual(actual.y, expected.y, accuracy: 1e-12, file: file, line: line)
  }
}
