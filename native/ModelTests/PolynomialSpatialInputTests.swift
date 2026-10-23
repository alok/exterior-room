// SPDX-License-Identifier: GPL-3.0-or-later
// Geometry/model checks, not actual gesture or hardware acceptance.
import XCTest
@testable import ExteriorRoomCore

final class PolynomialSpatialInputTests:XCTestCase {
  func testRootLocalDirectionMatchesBothSignedNappesAndD5Fixture() throws {
    for scale in [0.1,1.0,12.0,-1.0] {
      let z=try XCTUnwrap(PolynomialSpatialInput.upperPoint(direction:SIMD3<Double>(2,3,1)*scale))
      XCTAssertEqual(z.x,1,accuracy:1e-12); XCTAssertEqual(z.y,1,accuracy:1e-12)
    }
    XCTAssertEqual(PolynomialSpatialInput.upperPoint(direction:[0,2,0]),SIMD2(0,1))
    for p:SIMD3<Double> in [[0,0,0],[1,0,0],[2,1,0],[1,1,0],[.nan,1,0]] {
      XCTAssertNil(PolynomialSpatialInput.upperPoint(direction:p))
    }
  }
  func testStaticShellEnclosesAllAcceptedCollisionReachWithoutMovingOrigin() {
    let shell=PolynomialSpatialInput.shell()
    XCTAssertEqual(shell.positions.count,325); XCTAssertEqual(shell.indices.count,1728)
    XCTAssertTrue(shell.indices.allSatisfy{Int($0)<shell.positions.count})
    XCTAssertGreaterThan(PolynomialSpatialInput.shellInradius,2.3)
    for reach:Float in [0,2,5,20] {
      XCTAssertGreaterThanOrEqual(PolynomialSpatialInput.shellScale(reach:reach)*PolynomialSpatialInput.shellInradius,reach+0.1-1e-5)
    }
    XCTAssertTrue(PolynomialSpatialInput.shell(bands:1).positions.isEmpty)
  }
}
