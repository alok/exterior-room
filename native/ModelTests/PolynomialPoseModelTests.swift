// SPDX-License-Identifier: GPL-3.0-or-later
// Placement lifecycle tests use declared rigid matrices, never live tracking or synthesized input.
import XCTest
import simd
@testable import ExteriorRoomCore

@MainActor final class PolynomialPoseModelTests:XCTestCase {
  private func model() throws -> PolynomialModel {
    let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
    return PolynomialModel(cloudData:try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-cloud-r6.json")),
      inspectionData:try Data(contentsOf:native.appendingPathComponent("Resources/polynomial-default.json")),
      transport:{ _ in throw URLError(.notConnectedToInternet) })
  }
  private func measure(_ model:PolynomialModel,_ matrix:simd_float4x4=matrix_identity_float4x4) throws -> PolynomialModel.DevicePoseInstallToken {
    let request=try XCTUnwrap(model.beginDevicePoseQuery())
    XCTAssertTrue(model.acceptDevicePose(.success(matrix),for:request))
    return try XCTUnwrap(model.devicePoseInstallToken)
  }
  func testRendererOriginFramePreservesRootDirectionUnderTranslatedRotatedDevicePoseAndBothNappes() throws {
    var device=simd_float4x4(simd_quatf(angle:.pi/2,axis:[0,1,0]))
    device.columns.3=[1,2,3,1]
    let rootPoint=SIMD4<Float>(2,3,1,1)
    for (lower,expected) in [(false,SIMD4<Float>(-2,3,1,1)),(true,SIMD4<Float>(4,1,1,1))] {
      // This is the same full placement helper used by RealityKit, with independently calculated world points.
      let frame=PolynomialSpatialInput.originPlacement(devicePose:device,lower:lower)
      XCTAssertTrue(PolynomialDevicePoseQuery.isRigid(frame))
      let world=frame*rootPoint
      for i in 0..<4 { XCTAssertEqual(world[i],expected[i],accuracy:0.00001) }
      XCTAssertEqual(frame.columns.3,device.columns.3,"Nappe rotation must not rotate the device translation")
      let recovered=frame.inverse*expected
      for i in 0..<4 { XCTAssertEqual(recovered[i],rootPoint[i],accuracy:0.00001) }
      let root=try XCTUnwrap(PolynomialSpatialInput.upperPoint(direction:[Double(recovered.x),Double(recovered.y),Double(recovered.z)]))
      XCTAssertEqual(root.x,1,accuracy:0.00001);XCTAssertEqual(root.y,1,accuracy:0.00001)
    }
  }
  func testSpatialInputRequiresRendererInstallOfExactPoseAndPlacement() throws {
    let m=try model();m.spaceOpen=true;m.place(.origin(lower:false))
    let selected=m.selected,revision=m.sceneRevision
    m.beginSpatialDrag(direction:[0,2,0]);XCTAssertNil(m.actionPreview)
    let token=try measure(m)
    XCTAssertFalse(m.spatialPoseReady)
    m.beginSpatialDrag(direction:[0,2,0]);XCTAssertNil(m.actionPreview)
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(.init(epoch:token.epoch,id:UUID(),placement:token.placement)))
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(.init(epoch:token.epoch+1,id:token.id,placement:token.placement)))
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(.init(epoch:token.epoch,id:token.id,placement:.origin(lower:true))))
    XCTAssertTrue(m.acknowledgeDevicePoseInstalled(token));XCTAssertTrue(m.spatialPoseReady)
    m.beginSpatialDrag(direction:[0,2,0]);m.updateSpatialDrag(direction:[2,3,1],force:true)
    XCTAssertNotNil(m.actionPreview);XCTAssertTrue(m.ownsSpatialDrag)
    XCTAssertEqual(m.selected,selected);XCTAssertEqual(m.sceneRevision,revision)
    m.cancelSpatialDrag()
  }
  func testNappeFlipFreezesPoseButInvalidatesInputAndOldInstallAcknowledgement() throws {
    let m=try model();m.spaceOpen=true;m.place(.origin(lower:false))
    var pose=matrix_identity_float4x4;pose.columns.3=[0.4,1.7,-0.6,1]
    let upper=try measure(m,pose)
    XCTAssertTrue(m.acknowledgeDevicePoseInstalled(upper))
    m.beginSpatialDrag(direction:[0,2,0]);m.updateSpatialDrag(direction:[2,3,1],force:true)
    m.flipOriginNappe()
    XCTAssertNil(m.actionPreview);XCTAssertFalse(m.commitSpatialDrag());XCTAssertFalse(m.spatialPoseReady)
    XCTAssertEqual(m.currentDevicePose?.id,upper.id);XCTAssertEqual(m.placementEpoch,upper.epoch)
    XCTAssertEqual(m.currentDevicePose?.matrix.columns.3,pose.columns.3)
    XCTAssertNil(m.beginDevicePoseQuery(),"Flip must not start a second tracking session for this epoch")
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(upper))
    let lower=try XCTUnwrap(m.devicePoseInstallToken)
    XCTAssertTrue(m.acknowledgeDevicePoseInstalled(lower));XCTAssertTrue(m.spatialPoseReady)
    m.beginSpatialDrag(direction:[0,-2,0]);XCTAssertNotNil(m.actionPreview);m.cancelSpatialDrag()
  }
  func testLateQueryAndInstallCannotUnlockAfterOverviewLeaveOrReentry() throws {
    let m=try model();m.spaceOpen=true;m.place(.origin(lower:false))
    let old=try XCTUnwrap(m.beginDevicePoseQuery())
    m.place(.overview)
    XCTAssertFalse(m.acceptDevicePose(.success(matrix_identity_float4x4),for:old))
    m.place(.origin(lower:false));let middle=try measure(m)
    m.spaceOpen=false
    XCTAssertNil(m.currentDevicePose);XCTAssertFalse(m.acknowledgeDevicePoseInstalled(middle))
    m.spaceOpen=true
    let fresh=try XCTUnwrap(m.beginDevicePoseQuery())
    XCTAssertFalse(m.acceptDevicePose(.success(matrix_identity_float4x4),for:old))
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(middle))
    XCTAssertTrue(m.acceptDevicePose(.success(matrix_identity_float4x4),for:fresh))
    let freshToken=try XCTUnwrap(m.devicePoseInstallToken)
    XCTAssertNotEqual(freshToken.id,middle.id)
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(middle));XCTAssertFalse(m.spatialPoseReady)
    XCTAssertTrue(m.acknowledgeDevicePoseInstalled(freshToken))
  }
  func testPoseIsAcceptedOncePerEpochAndFailureNeverEnablesSpatialInput() throws {
    let m=try model();m.spaceOpen=true;m.place(.origin(lower:false))
    let request=try XCTUnwrap(m.beginDevicePoseQuery())
    XCTAssertFalse(m.acceptDevicePose(.failure(.notTracked),for:request))
    XCTAssertFalse(m.acceptDevicePose(.success(matrix_identity_float4x4),for:request),"Failure consumes the one-shot request")
    XCTAssertNil(m.beginDevicePoseQuery());XCTAssertFalse(m.spatialPoseReady)
    m.beginSpatialDrag(direction:[0,2,0]);XCTAssertNil(m.actionPreview)
    m.place(.origin(lower:false));let fresh=try XCTUnwrap(m.beginDevicePoseQuery())
    XCTAssertTrue(m.acceptDevicePose(.success(matrix_identity_float4x4),for:fresh))
    let id=m.currentDevicePose?.id
    var changed=matrix_identity_float4x4;changed.columns.3=[10,20,30,1]
    XCTAssertFalse(m.acceptDevicePose(.success(changed),for:fresh))
    XCTAssertEqual(m.currentDevicePose?.id,id);XCTAssertEqual(m.currentDevicePose?.matrix.columns.3,[0,0,0,1])
  }
  func testInvalidRigidResultAndResetPreserveExactSelectionBoundary() async throws {
    let m=try model();m.spaceOpen=true;m.place(.origin(lower:false))
    let request=try XCTUnwrap(m.beginDevicePoseQuery())
    var bad=matrix_identity_float4x4;bad.columns.0.x=2
    XCTAssertFalse(m.acceptDevicePose(.success(bad),for:request));XCTAssertNil(m.currentDevicePose)
    XCTAssertFalse(m.spatialPoseReady);XCTAssertEqual(m.selected,[1,-1,2])
    m.place(.origin(lower:false));let token=try measure(m);XCTAssertTrue(m.acknowledgeDevicePoseInstalled(token))
    m.beginSpatialDrag(direction:[0,2,0]);m.updateSpatialDrag(direction:[2,3,1],force:true)
    m.reset();await m.waitForPending()
    XCTAssertEqual(m.placement,.overview);XCTAssertNil(m.currentDevicePose);XCTAssertNil(m.actionPreview)
    XCTAssertFalse(m.acknowledgeDevicePoseInstalled(token));XCTAssertFalse(m.commitSpatialDrag())
  }
}
