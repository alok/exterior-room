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

  func testSourceRingsUsePrimitiveGeometryButKeepExactSignedInspectedIdentities() throws {
    let viewport = try fitted(), action = try rationalAction()
    for rows in [identityRows,try XCTUnwrap(action.coefficientRowsApprox)] {
      let original = try inspection("default")
      let baseline = try XCTUnwrap(Geometry.sourceSelectionRing(inspection:original,rows:rows,viewport:viewport))
      for name in ["positive_multiple","negative_partner"] {
        let detail = try inspection(name)
        let ring = try XCTUnwrap(Geometry.sourceSelectionRing(inspection:detail,rows:rows,viewport:viewport))
        close(ring.root,baseline.root); close(ring.center,baseline.center)
        XCTAssertEqual(ring.radius,baseline.radius,accuracy:1e-12)
        XCTAssertEqual(ring.sourceRingRadius,baseline.sourceRingRadius,accuracy:1e-12)
        XCTAssertEqual(ring.point.abc,detail.point,"The label identity must not become the positive primitive form")
        XCTAssertEqual(ring.point.delta,detail.delta); XCTAssertEqual(ring.point.divisor,detail.divisor)
        XCTAssertEqual(ring.point.kind,detail.kind == "lower" ? 3:2)
        XCTAssertNotEqual(ring.point.abc,original.point)
      }
    }
    let multiple = try inspection("positive_multiple")
    let primitiveRing = try XCTUnwrap(Geometry.sourceSelectionRing(inspection:multiple,rows:identityRows,viewport:viewport))
    close(primitiveRing.root,[0.5,sqrt(7)/2])
    XCTAssertEqual(primitiveRing.radius,7,accuracy:1e-12)
    XCTAssertEqual(primitiveRing.sourceRingRadius,11,accuracy:1e-12)
    // Canonical bodies still size the actual multiple; only source selected rings normalize it.
    let point = try XCTUnwrap(cloud().first { $0.abc == [2,0,2] })
    let canonical = try XCTUnwrap(Geometry.dots(points:[point],rows:identityRows,viewport:viewport).first)
    XCTAssertEqual(canonical.radius,3.5,accuracy:1e-12)
    XCTAssertEqual(canonical.ringRadius,6.5,accuracy:1e-12)
  }

  func testSourceRingSurvivesHiddenCatalogueIdentityAndUsesItsOwnMinimumRadius() throws {
    let viewport = try fitted(), detail = try inspection("source-seed")
    XCTAssertFalse(try cloud().contains { $0.abc == detail.point })
    let ring = try XCTUnwrap(Geometry.sourceSelectionRing(inspection:detail,rows:identityRows,viewport:viewport))
    XCTAssertEqual(ring.point.abc,[13,20,34]); XCTAssertEqual(ring.point.delta,-1368)
    close(ring.root,[-10.0/13,sqrt(1368)/26])
    XCTAssertEqual(ring.radius,7.0/13,accuracy:1e-12)
    XCTAssertEqual(ring.sourceRingRadius,5)
    XCTAssertEqual(ring.ringRadius,3.6,accuracy:1e-12,"The source minimum must not change canonical rings")
    let action = try rationalAction()
    let moved = try XCTUnwrap(Geometry.sourceSelectionRing(inspection:detail,
      rows:try XCTUnwrap(action.coefficientRowsApprox),viewport:viewport))
    // J([3,1;1,2])/5 maps this signed identity to (46,-116,259)/5.
    close(moved.root,[58.0/46,5*sqrt(1368)/92])
    XCTAssertEqual(moved.point.abc,detail.point)
  }

  func testSourceRingsRejectNonInteriorAndInvalidPresentationInputs() throws {
    let viewport = try fitted()
    for name in ["null_boundary","exterior"] {
      XCTAssertNil(Geometry.sourceSelectionRing(inspection:try inspection(name),rows:identityRows,viewport:viewport))
    }
    let detail = try inspection("negative_partner")
    XCTAssertNil(Geometry.sourceSelectionRing(inspection:detail,rows:[],viewport:viewport))
    XCTAssertNil(Geometry.sourceSelectionRing(inspection:detail,rows:Array(repeating:.nan,count:9),viewport:viewport))
    XCTAssertNil(Geometry.sourceSelectionRing(inspection:detail,rows:identityRows,viewport:viewport,sigma:0))
    XCTAssertNil(Geometry.sourceSelectionRing(inspection:detail,rows:identityRows,viewport:viewport,sigma:.infinity))
  }

  func testSourceBodyOpacityUsesDiscretePlaneIncidenceAndFootprintAttenuation() throws {
    let base = try unit()
    let member = PolynomialPoint(abc:base.abc,xyz:base.xyz,delta:base.delta,kind:base.kind,
      divisor:base.divisor,onPlane:true,necklace:true)
    let ordinary = dot(base,x:0,y:0,radius:7), onPlane = dot(member,x:0,y:0,radius:7)
    XCTAssertEqual(Geometry.sourceBodyOpacity(ordinary,crop:0.8,hasPlane:false),0.8,accuracy:1e-12)
    XCTAssertEqual(Geometry.sourceBodyOpacity(ordinary,crop:0.8,hasPlane:true),0.208,accuracy:1e-12)
    XCTAssertEqual(Geometry.sourceBodyOpacity(onPlane,crop:0.8,hasPlane:true),0.8,accuracy:1e-12)
    let tiny = dot(base,x:0,y:0,radius:0.3)
    XCTAssertEqual(Geometry.sourceBodyOpacity(tiny,crop:0.8,hasPlane:true),0.052,accuracy:1e-12)
    XCTAssertEqual(Geometry.sourceBodyOpacity(onPlane,crop:0,hasPlane:true),0)
    XCTAssertEqual(Geometry.sourceBodyOpacity(ordinary,crop:.nan,hasPlane:false),0)
  }

  func testSourcePickingUsesPackedPreRasterAlphaWithoutTinyFootprintAttenuation() throws {
    let point = try unit(), tiny = dot(point,x:0,y:0,radius:0.01)
    XCTAssertLessThan(tiny.opacity,0.05)
    XCTAssertEqual(Geometry.pickSource([tiny],at:.zero,hasPlane:false,crop:{ _ in 1 }),tiny)
    XCTAssertEqual(Geometry.pickSource([tiny],at:.zero,hasPlane:false,crop:{ _ in 0.05 }),tiny)
    // A value immediately below .05 rounds upward in the source's Float32 alpha buffer.
    XCTAssertEqual(Geometry.pickSource([tiny],at:.zero,hasPlane:false,crop:{ _ in Double(0.05).nextDown }),tiny)
    XCTAssertNil(Geometry.pickSource([tiny],at:.zero,hasPlane:false,crop:{ _ in 0.04999999 }))
    XCTAssertEqual(Geometry.pickSource([tiny],at:.zero,hasPlane:true,crop:{ _ in 0.2 }),tiny)
    XCTAssertNil(Geometry.pickSource([tiny],at:.zero,hasPlane:true,crop:{ _ in 0.19 }))
    XCTAssertNil(Geometry.pickSource([tiny],at:.zero,hasPlane:false,crop:{ _ in .nan }))
    XCTAssertNil(Geometry.pickSource([tiny],at:CGPoint(x:CGFloat.nan,y:0),hasPlane:false,crop:{ _ in 1 }))
  }

  func testSourcePickingUsesExpandedRadiusCappedScoreAndFirstSourceTie() throws {
    let point = try unit(), other = try XCTUnwrap(cloud().first { $0.abc == [1,-1,2] })
    let small = dot(point,x:0,y:0,radius:1), fartherLarge = dot(other,x:2,y:0,radius:5)
    XCTAssertEqual(Geometry.pickSource([small,fartherLarge],at:.zero,hasPlane:false,crop:{ _ in 1 }),fartherLarge)
    XCTAssertEqual(Geometry.pick([small,fartherLarge],at:.zero),small,"Canonical nearest/half-point tie stays unchanged")
    let tied = dot(point,x:-2,y:0,radius:5)
    XCTAssertEqual(Geometry.pickSource([fartherLarge,tied],at:.zero,hasPlane:false,crop:{ _ in 1 }),fartherLarge)
    XCTAssertEqual(Geometry.pickSource([tied,fartherLarge],at:.zero,hasPlane:false,crop:{ _ in 1 }),tied)
    let enormous = dot(other,x:20,y:0,radius:100), nearSmall = dot(point,x:3,y:0,radius:1)
    XCTAssertEqual(Geometry.pickSource([enormous,nearSmall],at:.zero,hasPlane:false,crop:{ _ in 1 }),nearSmall,
      "The radius bias stops increasing after radius12")
    let expanded = dot(point,x:14,y:0,radius:10)
    XCTAssertEqual(Geometry.pickSource([expanded],at:.zero,hasPlane:false,crop:{ _ in 1 }),expanded)
    XCTAssertNil(Geometry.pickSource([expanded],at:CGPoint(x:-0.00001,y:0),hasPlane:false,crop:{ _ in 1 }))
    XCTAssertNil(Geometry.pick([expanded],at:.zero),"Canonical hit radius has no source +4 expansion")
  }

  func testSourceDotsKeepCatalogueOrderWithoutChangingCanonicalRadiusSort() throws {
    let points = try cloud(), viewport = try fitted()
    let unit = try XCTUnwrap(points.first { $0.abc == [1,0,1] })
    let smaller = try XCTUnwrap(points.first { $0.abc == [2,1,1] })
    let source = Geometry.dots(points:[unit,smaller],rows:identityRows,viewport:viewport,preservingSourceOrder:true)
    XCTAssertEqual(source.map(\.point.abc),[[1,0,1],[2,1,1]])
    let canonical = Geometry.dots(points:[unit,smaller],rows:identityRows,viewport:viewport)
    XCTAssertEqual(canonical.map(\.point.abc),[[2,1,1],[1,0,1]])
  }

  func testSourceUpperHalfPlaneNumericAuditAgainstActualLeanInspectionInputs() throws {
    struct Fixture:Decodable {
      struct Viewport:Decodable { let width:Double,height:Double,scale:Double }
      struct Item:Decodable {
        struct Marker:Decodable { let screenXY:[Double],rawRadius:Double,ringRadius:Double,alpha:Double }
        struct Body:Decodable { let radius:Double,alpha:Double }
        let name:String,matrix:[Int],model:Int,abc:[Int],planeMember:Bool
        let cropFadeFloat32:Double?
        let marker:Marker?,body:Body?
      }
      let schema:String,sourceSHA256:String,viewport:Viewport,cases:[Item]
    }
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let fixture = try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:
      root.appendingPathComponent("lean/Polynomial/fixtures/source-roots-marker.json")))
    XCTAssertEqual(fixture.schema,"source-roots-marker-audit-v1")
    XCTAssertEqual(fixture.sourceSHA256,"f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b")
    let viewport = try XCTUnwrap(Geometry.Viewport(size:CGSize(width:240,height:600)))
    XCTAssertEqual(viewport.scale,fixture.viewport.scale,accuracy:1e-12)
    let names = ["unit-selected":"axis_interior","paired":"minimum_discriminant",
      "off-plane-upper":"default","absent-crop-selected":"source-seed",
      "null-selected":"null_boundary","exterior-selected":"exterior_symmetric"]
    var compared = 0
    for item in fixture.cases where item.model == 2 {
      guard let name = names[item.name] else { continue }
      let detail = try inspection(name)
      XCTAssertEqual(detail.point,item.abc)
      let rows:[Double]
      if item.matrix == [1,0,0,1] { rows = identityRows }
      else { rows = try XCTUnwrap(rationalAction().coefficientRowsApprox) }
      let ring = Geometry.sourceSelectionRing(inspection:detail,rows:rows,viewport:viewport)
      if let expected = item.marker {
        let actual = try XCTUnwrap(ring)
        close(actual.root,[(expected.screenXY[0]-fixture.viewport.width/2)/fixture.viewport.scale,
          (fixture.viewport.height/2-expected.screenXY[1])/fixture.viewport.scale])
        XCTAssertEqual(actual.radius,expected.rawRadius,accuracy:1e-12,item.name)
        XCTAssertEqual(actual.sourceRingRadius,expected.ringRadius,accuracy:1e-12,item.name)
        XCTAssertEqual(actual.point.abc,item.abc); XCTAssertEqual(expected.alpha,1)
      } else { XCTAssertNil(ring,item.name) }
      if let body = item.body, let ring {
        let base = ring.point
        let point = PolynomialPoint(abc:base.abc,xyz:base.xyz,delta:base.delta,kind:base.kind,
          divisor:base.divisor,onPlane:item.planeMember,necklace:false)
        let dot = try XCTUnwrap(Geometry.dots(points:[point],rows:rows,viewport:viewport).first)
        XCTAssertEqual(dot.radius,body.radius,accuracy:1e-12,item.name)
        XCTAssertEqual(Geometry.sourceBodyAlpha(point,crop:try XCTUnwrap(item.cropFadeFloat32),hasPlane:true),body.alpha,accuracy:1e-12,item.name)
      }
      compared += 1
    }
    XCTAssertEqual(compared,12,"Direct-source display audit, not Lean/kernel or app execution evidence")
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
  private func inspection(_ name:String) throws -> PolynomialInspection {
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with:resource("polynomial-test-cases.json")) as? [String:Any])
    let data = try JSONSerialization.data(withJSONObject:XCTUnwrap(object[name]))
    let detail = try JSONDecoder().decode(PolynomialInspection.self,from:data)
    XCTAssertTrue(detail.isValid)
    return detail
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
