@testable import SwiftMechanics
import Testing

@Suite struct InertiaTests {
    private func policy() throws -> InertiaValidationPolicy {
        try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 1e-12, relative: 1e-12), physicalityRelative: 1e-12)
    }

    @Test func primitiveAnalyticMoments() throws {
        let calculator: any MassPropertyCalculating = AnalyticMassCalculator()
        let box = try calculator.properties(of: .box(width: 2, depth: 3, height: 4), density: 5, policy: policy())
        #expect(box.mass == 120)
        #expect(box.inertiaAtCenter.m00 == 250)
        #expect(box.inertiaAtCenter.m11 == 200)
        #expect(box.inertiaAtCenter.m22 == 130)
        #expect(box.origin == .analyticPrimitive)
        let sphere = try calculator.properties(of: .sphere(radius: 2), density: 3, policy: policy())
        #expect(abs(sphere.mass - 32 * Double.pi) < 1e-12)
        #expect(abs(sphere.inertiaAtCenter.m00 - 51.2 * Double.pi) < 1e-12)
        let cylinder = try calculator.properties(of: .cylinder(radius: 2, height: 3), density: 4, policy: policy())
        #expect(abs(cylinder.mass - 48 * Double.pi) < 1e-12)
        #expect(abs(cylinder.inertiaAtCenter.m00 - 84 * Double.pi) < 1e-12)
        #expect(abs(cylinder.inertiaAtCenter.m22 - 96 * Double.pi) < 1e-12)
        let rectangle = try calculator.properties(of: .rectangle(width: 2, height: 3), arealDensity: 4)
        #expect(rectangle.mass == 24)
        #expect(rectangle.polarInertiaAtCenter == 26)
        let disk = try calculator.properties(of: .disk(radius: 2), arealDensity: 3)
        #expect(abs(disk.mass - 12 * Double.pi) < 1e-12)
        #expect(abs(disk.polarInertiaAtCenter - 24 * Double.pi) < 1e-12)
    }

    @Test func rotatedPhysicalityAndNonphysicalTensors() throws {
        let rotation = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 0.71)
        let valid = try InertiaTransformer().rotated(Matrix3(3, 0, 0, 0, 4, 0, 0, 0, 5), by: rotation)
        let accepted = try MassProperties3D(mass: 2, centerOfMass: .zero, inertiaAtCenter: valid, policy: policy())
        #expect(accepted.inertiaAtCenter.m01 == accepted.inertiaAtCenter.m10)
        let invalid = try InertiaTransformer().rotated(Matrix3(1, 0, 0, 0, 1, 0, 0, 0, 3), by: rotation)
        #expect(throws: ModelError.nonphysicalInertia) {
            try MassProperties3D(mass: 2, centerOfMass: .zero, inertiaAtCenter: invalid, policy: policy())
        }
        // Off-diagonal terms can violate realizability while diagonals appear physical.
        let secondMomentIndefinite = try Matrix3(2, 1.5, 0, 1.5, 2, 0, 0, 0, 2)
        #expect(throws: ModelError.nonphysicalInertia) {
            try MassProperties3D(mass: 2, centerOfMass: .zero, inertiaAtCenter: secondMomentIndefinite, policy: policy())
        }
        // Independent second-moment eigenbasis: negative eigenvalue -1e-7,
        // positive eigenvalues 2e-7 and 1. Every 1x1/2x2 principal minor is
        // positive, but determinant is tiny negative; per-minor tolerance is unsafe.
        let a = 1e-7, b = 2e-7
        let s00 = -a / 3 + b / 2 + 1 / 6.0
        let s11 = s00, s22 = -a / 3 + 2 / 3.0
        let s01 = -a / 3 - b / 2 + 1 / 6.0
        let s02 = -a / 3 - 1 / 3.0
        let trace = -a + b + 1
        let slenderInvalid = try Matrix3(trace - s00, -s01, -s02,
                                         -s01, trace - s11, -s02,
                                         -s02, -s02, trace - s22)
        #expect(throws: ModelError.nonphysicalInertia) {
            try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: slenderInvalid, policy: policy())
        }
        let planarDistribution = try Matrix3(1, 0, 0, 0, 2, 0, 0, 0, 3)
        _ = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: planarDistribution, policy: policy())
    }

    @Test func invalidPropertiesAndPolicy() throws {
        #expect(throws: ModelError.invalidMass) { try MassProperties3D(mass: 0, centerOfMass: .zero, inertiaAtCenter: .identity, policy: policy()) }
        #expect(throws: ModelError.invalidMass) { try MassProperties3D(mass: .infinity, centerOfMass: .zero, inertiaAtCenter: .identity, policy: policy()) }
        #expect(throws: ModelError.nonPositiveInertia) { try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .zero, policy: policy()) }
        #expect(throws: ModelError.nonPositiveInertia) { try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: Matrix3(0, 0, 0, 0, 1, 0, 0, 0, 1), policy: policy()) }
        #expect(throws: ModelError.asymmetricInertia) { try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: Matrix3(2, 1, 0, 0, 2, 0, 0, 0, 2), policy: policy()) }
        #expect(throws: ModelError.invalidInertiaPolicy) { try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0, relative: 0), physicalityRelative: 1) }
        #expect(throws: ModelError.nonPositiveInertia) { try MassProperties2D(mass: 1, centerX: 0, centerY: 0, polarInertiaAtCenter: 0) }
        let calculator = AnalyticMassCalculator()
        #expect(throws: ModelError.invalidDensity) { try calculator.properties(of: .sphere(radius: 1), density: -1, policy: policy()) }
        #expect(throws: ModelError.invalidDimensions) { try calculator.properties(of: .box(width: -1, depth: 1, height: 1), density: 1, policy: policy()) }
        #expect(throws: ModelError.invalidDimensions) { try calculator.properties(of: .cylinder(radius: .nan, height: 1), density: 1, policy: policy()) }
        #expect(throws: ModelError.invalidDimensions) { try calculator.properties(of: .disk(radius: 0), arealDensity: 1) }
        #expect(throws: ModelError.invalidDensity) { try calculator.properties(of: .rectangle(width: 1, height: 1), arealDensity: 0) }
    }

    @Test func separatedCompositionAndFrameLaw() throws {
        let calculator = AnalyticMassCalculator()
        let left = try CompoundPart3D(primitive: .sphere(radius: 1), density: 3 / (4 * Double.pi),
                                       primitiveToCompound: RigidTransform(rotation: .identity, translation: Vector3(-2, 0, 0)))
        let right = try CompoundPart3D(primitive: .sphere(radius: 1), density: 9 / (4 * Double.pi),
                                        primitiveToCompound: RigidTransform(rotation: .identity, translation: Vector3(2, 0, 0)))
        let composite = try calculator.compound(parts: [left, right], overlap: .requireDisjointBoundingBoxes, policy: policy())
        #expect(abs(composite.mass - 4) < 1e-12)
        #expect(abs(composite.centerOfMass.x - 1) < 1e-12)
        #expect(abs(composite.inertiaAtCenter.m00 - 1.6) < 1e-12)
        #expect(abs(composite.inertiaAtCenter.m11 - 13.6) < 1e-12)
        #expect(abs(composite.inertiaAtCenter.m22 - 13.6) < 1e-12)
        #expect(composite.origin == .compound(overlapPolicy: .requireDisjointBoundingBoxes))
        let transform = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: Double.pi / 2), translation: try Vector3(4, 5, 6))
        let transformed = try composite.transformed(by: transform, policy: policy())
        #expect(try transformed.centerOfMass.subtracting(Vector3(4, 6, 6)).magnitude() < 1e-12)
        #expect(abs(transformed.inertiaAtCenter.m00 - 13.6) < 1e-12)
        #expect(abs(transformed.inertiaAtCenter.m11 - 1.6) < 1e-12)
        #expect(transformed.origin == composite.origin)
    }

    @Test func overlapAdmissionAndExplicitAdditiveOrigin() throws {
        let calculator = AnalyticMassCalculator()
        let part = try CompoundPart3D(primitive: .box(width: 2, depth: 2, height: 2), density: 1, primitiveToCompound: .identity)
        #expect(throws: ModelError.ambiguousOverlap(first: 0, second: 1)) {
            try calculator.compound(parts: [part, part], overlap: .requireDisjointBoundingBoxes, policy: policy())
        }
        let additive = try calculator.compound(parts: [part, part], overlap: .additiveOverlappingMaterials, policy: policy())
        #expect(additive.mass == 16)
        #expect(additive.origin == .compound(overlapPolicy: .additiveOverlappingMaterials))
        #expect(abs(additive.inertiaAtCenter.m00 - 32 / 3) < 1e-12)
        #expect(throws: ModelError.emptyCompound) { try calculator.compound(parts: [], overlap: .requireDisjointBoundingBoxes, policy: policy()) }
        let hugeLocation = try CompoundPart3D(primitive: .sphere(radius: 1), density: 1,
                                               primitiveToCompound: RigidTransform(rotation: .identity, translation: Vector3(1e20, 1e20, 1e20)))
        #expect(throws: ModelError.ambiguousOverlap(first: 0, second: 1)) {
            try calculator.compound(parts: [hugeLocation, hugeLocation], overlap: .requireDisjointBoundingBoxes, policy: policy())
        }
        let rotated = try CompoundPart3D(primitive: .cylinder(radius: 1, height: 2), density: 1,
                                          primitiveToCompound: RigidTransform(rotation: UnitQuaternion(axis: .unitY, angle: Double.pi / 2), translation: Vector3(10, 0, 0)))
        _ = try calculator.compound(parts: [part, rotated], overlap: .requireDisjointBoundingBoxes, policy: policy())
    }
}
