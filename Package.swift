// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-mechanics",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftMechanics", targets: ["MechanicsCore", "MechanicsModel", "MechanicsNumerics"]),
        .library(name: "MechanicsCore", targets: ["MechanicsCore"]),
        .library(name: "MechanicsModel", targets: ["MechanicsModel"]),
        .library(name: "MechanicsNumerics", targets: ["MechanicsNumerics"]),
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
        .target(name: "MechanicsModel", dependencies: ["MechanicsCore"],
                exclude: ["DESIGN.md", "Identity/DESIGN.md", "Representations/DESIGN.md", "Inertia/DESIGN.md", "Bodies/DESIGN.md", "Coordinates/DESIGN.md"]),
        .target(name: "MechanicsNumerics", dependencies: ["MechanicsCore"],
                exclude: ["DESIGN.md", "LinearAlgebra/DESIGN.md", "Scaling/DESIGN.md", "Reduction/DESIGN.md"]),
        .executableTarget(name: "CoreVerification", dependencies: ["MechanicsCore"], exclude: ["DESIGN.md"]),
        .testTarget(name: "MechanicsCoreTests", dependencies: ["MechanicsCore"], exclude: ["DESIGN.md"]),
        .testTarget(name: "MechanicsModelTests", dependencies: ["MechanicsModel", "MechanicsCore"], exclude: ["DESIGN.md"]),
        .testTarget(name: "MechanicsNumericsTests", dependencies: ["MechanicsNumerics", "MechanicsCore"], exclude: ["DESIGN.md"]),
    ],
    swiftLanguageModes: [.v6]
)
