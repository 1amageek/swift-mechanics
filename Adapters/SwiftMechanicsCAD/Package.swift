// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SwiftMechanicsCAD",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SwiftMechanicsCAD", targets: ["SwiftMechanicsCAD"])],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/1amageek/swift-CAD.git",
                 revision: "295a724cdf0219c904007c2735f2b99ef08200ca"),
    ],
    targets: [
        .target(name: "SwiftMechanicsCAD", dependencies: [
            .product(name: "SwiftMechanics", package: "swift-mechanics"),
            .product(name: "CADCore", package: "swift-cad"),
            .product(name: "CADGeometry", package: "swift-cad"),
            .product(name: "CADTopology", package: "swift-cad"),
            .product(name: "CADIR", package: "swift-cad"),
            .product(name: "CADModeling", package: "swift-cad"),
            .product(name: "CADKernel", package: "swift-cad"),
        ], exclude: ["DESIGN.md", "GeometryAdmission/DESIGN.md", "GearBindings/DESIGN.md", "GearReinitialization"]),
        .testTarget(name: "SwiftMechanicsCADTests", dependencies: [
            "SwiftMechanicsCAD",
            .product(name: "SwiftMechanics", package: "swift-mechanics"),
            .product(name: "CADCore", package: "swift-cad"),
            .product(name: "CADGeometry", package: "swift-cad"),
            .product(name: "CADTopology", package: "swift-cad"),
            .product(name: "CADIR", package: "swift-cad"),
            .product(name: "CADModeling", package: "swift-cad"),
            .product(name: "CADKernel", package: "swift-cad"),
        ], exclude: ["DESIGN.md", "GearBindings/DESIGN.md", "GearReinitialization"]),
    ]
)
