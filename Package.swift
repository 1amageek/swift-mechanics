// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-mechanics",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftMechanics", targets: ["MechanicsCore"]),
        .library(name: "MechanicsCore", targets: ["MechanicsCore"]),
        .executable(name: "mechanics-core-verification", targets: ["CoreVerification"]),
    ],
    targets: [
        .target(
            name: "CMechanicsMath",
            exclude: ["DESIGN.md"],
            linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]
        ),
        .target(name: "MechanicsCore", dependencies: ["CMechanicsMath"],
                exclude: ["DESIGN.md", "Diagnostics/DESIGN.md", "Geometry/DESIGN.md", "Spatial/DESIGN.md", "Units/DESIGN.md"]),
        .executableTarget(name: "CoreVerification", dependencies: ["MechanicsCore"], exclude: ["DESIGN.md"]),
        .testTarget(name: "MechanicsCoreTests", dependencies: ["MechanicsCore"], exclude: ["DESIGN.md"]),
    ],
    swiftLanguageModes: [.v6]
)
