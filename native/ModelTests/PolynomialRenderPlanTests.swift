// SPDX-License-Identifier: GPL-3.0-or-later
// Pure renderer tests using accepted Lean fixtures. They establish no physical-device or gesture behavior.
import Foundation
import XCTest
@testable import ExteriorRoomCore

final class PolynomialRenderPlanTests: XCTestCase {
  private typealias Plan = PolynomialRenderPlan
  private let identityRows: [Double] = [1,0,0,0,1,0,0,0,1]

  func testActualR6AndRationalActionPickTheOriginalSignedIdentity() throws {
    let points = try cloud(), action = try rationalAction()
    for rows in [identityRows, try XCTUnwrap(action.coefficientRowsApprox)] {
      let snapshot = try make(points, rows: rows)
      XCTAssertEqual(snapshot.glyphs.map(\.point), points)
      for glyph in snapshot.glyphs {
        XCTAssertEqual(snapshot.pick(at: glyph.position), glyph.point,
          "A hit at an accepted glyph's center must preserve its signed, unreduced identity.")
      }
      for abc in [[1,-1,2],[-1,1,-2],[1,0,1],[-1,0,-1],[2,0,2]] {
        let glyph = try XCTUnwrap(snapshot.glyphs.first { $0.point.abc == abc })
        XCTAssertEqual(snapshot.pick(at: glyph.position)?.abc, abc)
      }
    }
    let transformed = try make(points, rows: XCTUnwrap(action.coefficientRowsApprox))
    let selected = try XCTUnwrap(transformed.glyphs.first { $0.point.abc == action.point })
    // The exact exported D=5 receipt supplies XYZ numerators [23,30,14]; Float conversion is rendering only.
    XCTAssertEqual(action.xyzNumerator, [23,30,14])
    close(selected.position, SIMD3<Float>(23,30,14) * (transformed.scale / 5))
    XCTAssertEqual(transformed.pick(at: selected.position)?.abc, [1,-1,2])
    XCTAssertNotEqual(transformed.pick(at: selected.position)?.abc, [8,-23,22])
  }

  func testRGBBatchesPartitionEveryGlyphWithoutDroppingSignsOrMultiples() throws {
    let points = try cloud()
    for palette in ["viridis","reference"] {
      for colorLower in [false,true] {
        let snapshot = try make(points, colorLower: colorLower, palette: palette)
        let indices = snapshot.batches.values.flatMap { $0 }
        XCTAssertEqual(indices.sorted(), Array(points.indices))
        XCTAssertEqual(Set(indices).count, points.count)
        XCTAssertGreaterThanOrEqual(snapshot.batches.count, 4)
        XCTAssertLessThan(snapshot.batches.count, points.count)
        for (key, batch) in snapshot.batches {
          for index in batch {
            XCTAssertEqual(UInt64(snapshot.glyphs[index].colorKey), key)
            let expected = PolynomialAppearance.color(points[index], colorLower: colorLower, palette: palette)
            let displayed = Plan.color(UInt32(key & 0xFFFFFF))
            for component in 0..<3 {
              XCTAssertEqual(displayed[component], expected[component], accuracy: 0.5/255 + 1e-12,
                "Batch grouping may quantize to RGB8 but must preserve each semantic color.")
            }
          }
        }
        let boundary = try XCTUnwrap(snapshot.glyphs.first { $0.point.kind == 0 })
        let exterior = try XCTUnwrap(snapshot.glyphs.first { $0.point.kind == 1 })
        XCTAssertEqual(boundary.colorKey, palette == "reference" ? 0xd6bd69 : 0xf4f2ff)
        XCTAssertEqual(exterior.colorKey, palette == "reference" ? 0x448abb : 0x7a5230)
        if !colorLower {
          let lower = try XCTUnwrap(snapshot.glyphs.first { $0.point.kind == 3 })
          XCTAssertEqual(lower.colorKey, palette == "reference" ? 0x64717d : 0x4d3a46)
        }
      }
    }
  }

  func testInstanceFactorsPreserveMultiplicityAndOriginSizeUnderAcceptedAction() throws {
    let points = try cloud(), ordinary = try make(points)
    let unit = try XCTUnwrap(ordinary.glyphs.first { $0.point.abc == [1,0,1] })
    let multiple = try XCTUnwrap(ordinary.glyphs.first { $0.point.abc == [2,0,2] })
    let lowerMultiple = try XCTUnwrap(ordinary.glyphs.first { $0.point.abc == [-2,0,-2] })
    XCTAssertEqual(unit.factor, 1)
    XCTAssertEqual(multiple.factor, 0.72, accuracy: 1e-6)
    XCTAssertEqual(lowerMultiple.factor, 1)
    let colored = try make(points, starSize: 2, colorLower: true)
    XCTAssertEqual(try XCTUnwrap(colored.glyphs.first { $0.point.abc == [-2,0,-2] }).factor, 1.44, accuracy: 1e-6)
    let origin = try make(points, origin: true)
    XCTAssertEqual(try XCTUnwrap(origin.glyphs.first { $0.point.abc == [1,0,1] }).factor, 0.4, accuracy: 1e-6)
    let transformedOrigin = try make(points, rows: XCTUnwrap(rationalAction().coefficientRowsApprox), origin: true)
    let transformedUnit = try XCTUnwrap(transformedOrigin.glyphs.first { $0.point.abc == [1,0,1] })
    XCTAssertEqual(transformedUnit.factor, Float(0.4*sqrt(2.0/3)), accuracy: 1e-6)
    XCTAssertGreaterThanOrEqual(transformedUnit.collisionRadius, 0.0125)
  }

  func testProjectionAllocatesOnlyWhenRequestedAndUsesAcceptedTransformedGeometry() throws {
    let points = try cloud(), rows = try XCTUnwrap(rationalAction().coefficientRowsApprox)
    let hidden = try make(points, rows: rows), shown = try make(points, rows: rows, projection: true)
    XCTAssertTrue(hidden.radialPositions.isEmpty)
    XCTAssertEqual(shown.glyphs.map(\.point), hidden.glyphs.map(\.point))
    XCTAssertEqual(shown.glyphs.map(\.position), hidden.glyphs.map(\.position))
    XCTAssertEqual(shown.radialPositions.count, points.filter { $0.delta < 0 }.count)
    for position in shown.radialPositions {
      XCTAssertTrue(finite(position))
      XCTAssertEqual(position.y, 4*shown.scale, accuracy: 1e-6)
    }
    let unit = try XCTUnwrap(points.first { $0.abc == [1,0,1] })
    let lower = try XCTUnwrap(points.first { $0.abc == [-1,0,-1] })
    let pair = try make([unit,lower], rows: rows, projection: true)
    XCTAssertEqual(pair.radialPositions.count, 2)
    close(pair.radialPositions[0], [8*pair.scale/3,4*pair.scale,4*pair.scale/3])
    close(pair.radialPositions[0], pair.radialPositions[1])
    XCTAssertEqual(pair.glyphs.map(\.point.abc), [[1,0,1],[-1,0,-1]],
      "Coincident projection dots must not merge the signed 3D identities.")
  }

  func testPickingHonorsChunkRangeDistanceAndDeterministicTies() throws {
    let points = try cloud(), snapshot = try make(points)
    let index = try XCTUnwrap(snapshot.glyphs.firstIndex { $0.point.abc == [-1,0,-1] })
    let glyph = snapshot.glyphs[index]
    XCTAssertEqual(snapshot.pick(at: glyph.position, range: index..<(index+1)), glyph.point)
    XCTAssertNil(snapshot.pick(at: glyph.position, range: 0..<0))
    XCTAssertNil(snapshot.pick(at: glyph.position + SIMD3<Float>(glyph.collisionRadius*1.02,0,0), range: index..<(index+1)))
    XCTAssertEqual(snapshot.pick(at: glyph.position + SIMD3<Float>(glyph.collisionRadius,0,0), range: index..<(index+1)), glyph.point)
    XCTAssertNil(snapshot.pick(at: [.nan,0,0]))
    XCTAssertNil(snapshot.pick(at: [0,.infinity,0]))
    let positive = try XCTUnwrap(points.first { $0.abc == [1,0,1] })
    // Deliberately coincident UI proxies test tie handling only, not a mathematical catalogue.
    let tied = Plan.Snapshot(glyphs: [
      Plan.Glyph(point:glyph.point,position:.zero,factor:1,colorKey:0,opacity:1),
      Plan.Glyph(point:positive,position:.zero,factor:1,colorKey:0,opacity:1)
    ], batches: [0:[0,1]], materialAlpha:[:], radialPositions: [], scale: snapshot.scale)
    XCTAssertEqual(tied.pick(at: .zero)?.abc, [-1,0,-1])
    XCTAssertEqual(tied.pick(at: .zero, range: 1..<2)?.abc, [1,0,1])
  }

  func testCollisionChunksStayWithinUInt16CapacityWithOutwardFiniteTriangles() throws {
    let point = try XCTUnwrap(cloud().first { $0.abc == [1,0,1] })
    let count = Plan.collisionChunkSize+1
    // Repeated accepted identity is intentional: this is a synthetic buffer-capacity test, not catalogue data.
    let glyphs = (0..<count).map { index in
      Plan.Glyph(point:point,position:[Float(index)*0.05,0,0],factor:1,colorKey:0,opacity:1)
    }
    let snapshot = Plan.Snapshot(glyphs:glyphs,batches:[0:Array(0..<count)],materialAlpha:[:],radialPositions:[],scale:1)
    let chunks = Plan.collisionChunks(snapshot)
    XCTAssertEqual(chunks.count, 2)
    XCTAssertEqual(chunks.flatMap { Array($0.range) }, Array(glyphs.indices))
    for chunk in chunks {
      XCTAssertLessThanOrEqual(chunk.positions.count, Int(UInt16.max)+1)
      XCTAssertEqual(chunk.positions.count, chunk.range.count*6)
      XCTAssertEqual(chunk.indices.count, chunk.range.count*24)
      XCTAssertTrue(chunk.positions.allSatisfy(finite))
      XCTAssertTrue(chunk.indices.allSatisfy { Int($0) < chunk.positions.count })
      for local in Set([0,chunk.range.count-1]) {
        let glyph = glyphs[chunk.range.lowerBound+local]
        for vertex in chunk.positions[(local*6)..<(local*6+6)] {
          XCTAssertEqual(length(vertex-glyph.position), glyph.collisionRadius, accuracy: 0.00002)
        }
        for triangle in stride(from:local*24,to:(local+1)*24,by:3) {
          let a = chunk.positions[Int(chunk.indices[triangle])]
          let b = chunk.positions[Int(chunk.indices[triangle+1])]
          let c = chunk.positions[Int(chunk.indices[triangle+2])]
          let normal = cross(b-a,c-a), outward = (a+b+c)/3-glyph.position
          XCTAssertGreaterThan(dot(normal,outward), 0, "Collision proxy winding must face outward.")
        }
      }
    }
    XCTAssertEqual(chunks[1].indices.max(), 5, "Each chunk restarts vertex indexing, avoiding UInt16 overflow.")
    XCTAssertEqual(snapshot.pick(at:glyphs.last!.position,range:chunks[1].range)?.abc, point.abc)
    XCTAssertNil(snapshot.pick(at:glyphs[0].position,range:chunks[1].range))
  }

  func testSharedSphereHasFiniteBoundedVerticesAndOutwardNondegenerateFaces() {
    let radius: Float = 0.0075, sphere = Plan.sphere(radius: radius)
    XCTAssertFalse(sphere.positions.isEmpty)
    XCTAssertEqual(sphere.indices.count % 3, 0)
    XCTAssertTrue(sphere.positions.allSatisfy(finite))
    for vertex in sphere.positions { XCTAssertEqual(length(vertex), radius, accuracy: 1e-8) }
    XCTAssertTrue(sphere.indices.allSatisfy { Int($0) < sphere.positions.count })
    for triangle in stride(from:0,to:sphere.indices.count,by:3) {
      let a = sphere.positions[Int(sphere.indices[triangle])]
      let b = sphere.positions[Int(sphere.indices[triangle+1])]
      let c = sphere.positions[Int(sphere.indices[triangle+2])]
      let normal = cross(b-a,c-a)
      XCTAssertGreaterThan(length(normal), 0)
      XCTAssertGreaterThan(dot(normal,(a+b+c)/3), 0, "Sphere triangles must face outward with back-face culling.")
    }
  }

  func testSourceMorphKeepsMaterialPartitionsStableWhilePositionsAndAlphaChange() throws {
    let (page,_,_)=try catalogue(matrix:[1,0,0,1])
    var snapshots:[Plan.Snapshot]=[]
    for progress in [0.0,0.5,1.0] {
      let settings=PolynomialSourceMorph.Settings(depth:6,progress:progress,whole:true)
      snapshots.append(try XCTUnwrap(Plan.make(points:page.points,rows:identityRows,radius:6,origin:false,
        starSize:1,colorLower:false,palette:"viridis",normal:nil,keep:[],projection:progress > 0,
        catalogue:page.metadata,sourceMorph:settings)))
    }
    XCTAssertEqual(snapshots[0].batches,snapshots[1].batches)
    XCTAssertEqual(snapshots[1].batches,snapshots[2].batches)
    XCTAssertNotEqual(snapshots[0].materialAlpha,snapshots[2].materialAlpha)
    for snapshot in snapshots {
      XCTAssertTrue(snapshot.radialPositions.isEmpty,"Source projection moves original glyphs; no duplicate overlay")
      XCTAssertTrue(snapshot.materialAlpha.values.allSatisfy {(0...1).contains($0)})
    }
    let i=try XCTUnwrap(page.points.firstIndex{$0.abc == [1,0,1]})
    XCTAssertEqual(snapshots[0].glyphs[i].opacity,0,"Whole radial fade at this R6 extension hides unit body, not its separate selected marker")
    XCTAssertGreaterThan(snapshots[2].glyphs[i].opacity,0)
    XCTAssertEqual(snapshots[2].glyphs[i].position.y,Float(3.6)*snapshots[2].scale,accuracy:1e-6)
  }

  func testSourceCatalogueVisibilityMatchesAuditedCountsWithoutDiscardingIdentities() throws {
    for matrix in [[1,0,0,1],[3,1,1,2]] {
      let (page, expectedUpper, expectedOther) = try catalogue(matrix: matrix)
      let rows = page.metadata.coefficientRows.map { Double($0)/Double(page.metadata.denominator) }
      let snapshot = try XCTUnwrap(Plan.make(points:page.points,rows:rows,radius:6,origin:false,
        starSize:1,colorLower:false,palette:"viridis",normal:nil,keep:[],projection:true,catalogue:page.metadata))
      XCTAssertEqual(snapshot.glyphs.map(\.point), page.points)
      let visibleIndices = snapshot.glyphs.indices.filter { snapshot.glyphs[$0].opacity > 0 }
      XCTAssertEqual(snapshot.batches.values.flatMap { $0 }.sorted(), visibleIndices)
      // Both audited identity/D5 catalogues have 66 upper + 14 other visible forms in the
      // browser Float32 display path. Sub-ulp Double smoothstep residues are not extra glyphs.
      XCTAssertEqual(expectedUpper, 66)
      XCTAssertEqual(expectedOther, 14)
      XCTAssertEqual(visibleIndices.filter { snapshot.glyphs[$0].point.kind == 2 }.count, expectedUpper)
      XCTAssertEqual(visibleIndices.filter { snapshot.glyphs[$0].point.kind != 2 }.count, expectedOther)
      XCTAssertTrue(snapshot.glyphs.allSatisfy { $0.opacity.isFinite && (0...1).contains($0.opacity) })
      XCTAssertGreaterThan(snapshot.glyphs.filter { $0.opacity == 0 }.count, 0,
        "The padded buffer must retain identities beyond the visible source crop.")
      XCTAssertEqual(snapshot.radialPositions.count, visibleIndices.filter {
        snapshot.glyphs[$0].point.kind == 2 && snapshot.glyphs[$0].point.divisor == 1
      }.count, "Source root/projection presentation includes only primitive upper base identities.")
      XCTAssertEqual(snapshot.radialPositions.count, 63)
      let chunks = Plan.collisionChunks(snapshot)
      XCTAssertEqual(chunks.reduce(0) { $0+$1.positions.count }, visibleIndices.count*6)
      XCTAssertEqual(chunks.reduce(0) { $0+$1.indices.count }, visibleIndices.count*24)
      for glyph in snapshot.glyphs {
        if glyph.opacity > 0 { XCTAssertEqual(snapshot.pick(at:glyph.position), glyph.point) }
        else { XCTAssertNil(snapshot.pick(at:glyph.position)) }
      }
    }
  }

  func testExactD5CutoffFormsHaveNoInvisiblePickProxies() throws {
    let (page, _, _) = try catalogue(matrix: [3,1,1,2])
    let numerators = page.metadata.coefficientRows, denominator = page.metadata.denominator
    // Identify exact boundary examples from the real Lean receipt. This is only a regression
    // predicate over exported data, never a replacement catalogue or accepted action.
    let boundary = page.points.filter { point in
      let image = (0..<3).map { row in
        numerators[row*3]*point.abc[0]+numerators[row*3+1]*point.abc[1]+numerators[row*3+2]*point.abc[2]
      }
      return point.kind == 2 ? image[0]+image[2] == page.metadata.depth*denominator
        : 2*image[0]*image[0]+image[1]*image[1]+2*image[2]*image[2]
          == page.metadata.otherRadius*page.metadata.otherRadius*denominator*denominator
    }
    XCTAssertEqual(boundary.filter { $0.kind == 2 }.count, 51)
    XCTAssertEqual(boundary.filter { $0.kind != 2 }.count, 5)
    let rows = numerators.map { Double($0)/Double(denominator) }
    let snapshot = try XCTUnwrap(Plan.make(points:boundary,rows:rows,radius:6,origin:false,
      starSize:1,colorLower:false,palette:"viridis",normal:nil,keep:[],projection:true,catalogue:page.metadata))
    XCTAssertEqual(snapshot.glyphs.map(\.point), boundary)
    for glyph in snapshot.glyphs {
      XCTAssertEqual(glyph.opacity, 0, "Exact cutoff identity \(glyph.point.id) must remain hidden.")
      XCTAssertNil(snapshot.pick(at:glyph.position))
    }
    XCTAssertTrue(snapshot.batches.isEmpty)
    XCTAssertTrue(snapshot.radialPositions.isEmpty)
    XCTAssertTrue(Plan.collisionChunks(snapshot).isEmpty)
  }

  func testAllHiddenActualSourcePointsGenerateNoCollisionMesh() throws {
    let (page, _, _) = try catalogue(matrix: [1,0,0,1])
    // This exact accepted base point lies at y=6: present in the padded catalogue, zero display opacity.
    let point = try XCTUnwrap(page.points.first { $0.abc == [1,-4,5] })
    let snapshot = try XCTUnwrap(Plan.make(points:[point],rows:identityRows,radius:6,origin:false,
      starSize:1,colorLower:false,palette:"viridis",normal:nil,keep:[],projection:true,catalogue:page.metadata))
    XCTAssertEqual(snapshot.glyphs.count, 1)
    XCTAssertEqual(snapshot.glyphs[0].point, point)
    XCTAssertEqual(snapshot.glyphs[0].opacity, 0)
    XCTAssertTrue(snapshot.batches.isEmpty)
    XCTAssertTrue(snapshot.radialPositions.isEmpty)
    XCTAssertNil(snapshot.pick(at:snapshot.glyphs[0].position))
    XCTAssertTrue(Plan.collisionChunks(snapshot).isEmpty,
      "Do not send an empty static collision mesh to RealityKit and abort the entire picking update.")
  }

  func testInvalidRenderInputsAndFloatOverflowAreRejectedBeforeInstanceBuffers() throws {
    let point = try XCTUnwrap(cloud().first { $0.abc == [1,0,1] })
    for radius in [0,-1] { XCTAssertNil(raw([point], radius: radius)) }
    for starSize in [0,-1,Double.nan,Double.infinity,Double.greatestFiniteMagnitude] {
      XCTAssertNil(raw([point], starSize: starSize))
    }
    XCTAssertNil(raw([point], rows: []))
    XCTAssertNil(raw([point], rows: [.nan,0,0,0,1,0,0,0,1]))
    XCTAssertNil(raw([point], rows: [1e40,0,0,0,1,0,0,0,1e40]))
    XCTAssertNil(raw(Array(repeating:point,count:Plan.maximumPoints+1)), "Capacity failures must reject the whole snapshot rather than truncate identities.")
  }

  private func raw(_ points:[PolynomialPoint],rows:[Double]? = nil,radius:Int = 6,origin:Bool = false,
                   starSize:Double = 1,colorLower:Bool = false,palette:String = "viridis",projection:Bool = false) -> Plan.Snapshot? {
    Plan.make(points:points,rows:rows ?? identityRows,radius:radius,origin:origin,starSize:starSize,
      colorLower:colorLower,palette:palette,normal:nil,keep:[],projection:projection)
  }
  private func make(_ points:[PolynomialPoint],rows:[Double]? = nil,radius:Int = 6,origin:Bool = false,
                    starSize:Double = 1,colorLower:Bool = false,palette:String = "viridis",projection:Bool = false) throws -> Plan.Snapshot {
    try XCTUnwrap(raw(points,rows:rows,radius:radius,origin:origin,starSize:starSize,colorLower:colorLower,palette:palette,projection:projection))
  }
  private func cloud() throws -> [PolynomialPoint] {
    let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    let cloud = try JSONDecoder().decode(PolynomialCloud.self,from:Data(contentsOf:native.appendingPathComponent("Resources/polynomial-cloud-r6.json")))
    XCTAssertTrue(cloud.isValid)
    return cloud.points
  }
  private func rationalAction() throws -> PolynomialAction {
    struct Fixture: Decodable {
      struct Entry: Decodable { let name:String; let response:PolynomialAction }
      let cases:[Entry]
    }
    let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    let fixture = try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:native.appendingPathComponent("Resources/polynomial-action-cases.json")))
    let action = try XCTUnwrap(fixture.cases.first { $0.name == "rational/default" }?.response)
    XCTAssertTrue(action.isValid)
    return action
  }
  private func catalogue(matrix:[Int]) throws -> (PolynomialCataloguePage,Int,Int) {
    let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("lean/Polynomial/fixtures")
    let fixture = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("catalogue-native-cases.json"))) as? [String:Any])
    let entries = try XCTUnwrap(fixture["cases"] as? [[String:Any]])
    let entry = try XCTUnwrap(entries.first { entry in
      guard let request = entry["request"] as? [String:Any] else { return false }
      return request["op"] as? String == "catalogue" && request["matrix"] as? [Int] == matrix
        && request["depth"] as? Int == 6 && (request["whole"] as? Bool ?? true)
        && (request["offset"] as? Int ?? 0) == 0 && (request["limit"] as? Int ?? 16384) == 16384
    })
    let page = try JSONDecoder().decode(PolynomialCataloguePage.self,
      from:JSONSerialization.data(withJSONObject:XCTUnwrap(entry["response"])))
    XCTAssertTrue(page.isValid)
    let audit = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("source-recrop-audit.json"))) as? [String:Any])
    let audited = try XCTUnwrap(try XCTUnwrap(audit["cases"] as? [[String:Any]]).first { $0["matrix"] as? [Int] == matrix })
    return (page,try XCTUnwrap(audited["visibleUpper"] as? Int),try XCTUnwrap(audited["visibleOther"] as? Int))
  }
  private func finite(_ value:SIMD3<Float>) -> Bool { value.x.isFinite && value.y.isFinite && value.z.isFinite }
  private func dot(_ a:SIMD3<Float>,_ b:SIMD3<Float>) -> Float { a.x*b.x+a.y*b.y+a.z*b.z }
  private func cross(_ a:SIMD3<Float>,_ b:SIMD3<Float>) -> SIMD3<Float> {
    [a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x]
  }
  private func length(_ value:SIMD3<Float>) -> Float { sqrt(dot(value,value)) }
  private func close(_ actual:SIMD3<Float>,_ expected:SIMD3<Float>) {
    for component in 0..<3 { XCTAssertEqual(actual[component],expected[component],accuracy:1e-6) }
  }
}
