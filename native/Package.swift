// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ExteriorRoomCore", platforms: [.macOS(.v15)],
  products: [.library(name: "ExteriorRoomCore", targets: ["ExteriorRoomCore"])],
  targets: [
    .target(name: "ExteriorRoomCore", path: "Sources", exclude: ["ExteriorRoomApp.swift", "ExteriorSpace.swift", "PolynomialRoomApp.swift", "PolynomialSpace.swift", "PolynomialTransformControls.swift", "PolynomialRootsView.swift"], sources: ["LeanModel.swift", "PolynomialModel.swift", "PolynomialAppearance.swift", "PolynomialViridis.swift", "PolynomialAction.swift", "PolynomialRootsGeometry.swift", "PolynomialRenderPlan.swift", "PolynomialCatalogue.swift"]),
    .testTarget(name: "ExteriorRoomCoreTests", dependencies: ["ExteriorRoomCore"], path: "ModelTests", exclude:["Fixtures"])
  ])
