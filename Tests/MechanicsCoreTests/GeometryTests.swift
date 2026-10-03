import MechanicsCore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct GeometryTests {
    @Test func vectorRangeAndDegeneracy() throws {
        let huge = try Vector3(.greatestFiniteMagnitude, .greatestFiniteMagnitude, 0).normalized()
        #expect(abs(huge.x - 1 / 2.0.squareRoot()) < 1e-15)
        #expect(abs(huge.y - huge.x) < 1e-15)
        let tiny = try Vector3(Double.leastNonzeroMagnitude, 0, 0).normalized()
        #expect(tiny == .unitX)
        #expect(try Vector3.unitX.cross(.unitY) == .unitZ)
        #expect(throws: CoreError.degenerateVector) { try Vector3.zero.normalized() }
        #expect(throws: CoreError.nonFiniteInput) { try Vector3(.nan, 0, 0) }
        #expect(throws: CoreError.nonFiniteResult) { try Vector3(.greatestFiniteMagnitude, 0, 0).scaled(by: 2) }
    }

    @Test func matrixInverseMatchesManufacturedSystem() throws {
        let matrix = try Matrix3(4, 1, 2, 0, 3, -1, 2, 0, 5)
        let operatorValue: any Matrix3Operating = matrix
        let expected = try Vector3(2, -3, 4)
        let rightHandSide = try matrix.applying(to: expected)
        let recovered = try operatorValue.inverted(relativeTolerance: 1e-14).applying(to: rightHandSide)
        #expect(try recovered.subtracting(expected).magnitude() < 1e-12)
        let product = try matrix.multiplied(by: matrix.inverted(relativeTolerance: 1e-14))
        #expect(try product.subtracting(.identity).maximumMagnitude < 1e-12)
        let scaled = try matrix.scaled(by: 1e200)
        let largeInverse = try scaled.inverted(relativeTolerance: 1e-14)
        #expect(try scaled.multiplied(by: largeInverse).subtracting(.identity).maximumMagnitude < 1e-12)
        #expect(throws: CoreError.singularMatrix) { try Matrix3.zero.inverted(relativeTolerance: 0) }
        #expect(throws: CoreError.invalidTolerance) { try matrix.inverted(relativeTolerance: .nan) }
        #expect(throws: CoreError.invalidIndex) { try matrix.element(row: 3, column: 0) }
        #expect(throws: CoreError.nonFiniteResult) { try Matrix3.identity.scaled(by: .greatestFiniteMagnitude).scaled(by: 2) }
    }

    @Test func quaternionAxisSignAndMatrixBranches() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-13, relative: 1e-13)
        for axis in [Vector3.unitX, .unitY, .unitZ, try Vector3(1, 2, 3).normalized()] {
            for angle in [0.1, 1.0, Double.pi, 1e-10] {
                let q = try UnitQuaternion(axis: axis, angle: angle)
                let recovered = try UnitQuaternion(matrix: q.matrix(), tolerance: tolerance)
                #expect(try recovered.matrix().subtracting(q.matrix()).maximumMagnitude < 1e-12)
                #expect(try q.rotationVector().subtracting(q.negated().rotationVector()).magnitude() < 1e-12)
            }
        }
        let quarterTurn = try UnitQuaternion(axis: .unitZ, angle: .pi / 2)
        #expect(try quarterTurn.rotating(.unitX).subtracting(.unitY).magnitude() < 1e-15)
        #expect(throws: CoreError.degenerateQuaternion) { try UnitQuaternion(w: 0, x: 0, y: 0, z: 0) }
        #expect(throws: CoreError.degenerateVector) { try UnitQuaternion(axis: .zero, angle: 1) }
        #expect(throws: CoreError.nonRigidMatrix) { try UnitQuaternion(matrix: Matrix3.identity.scaled(by: 2), tolerance: tolerance) }
        #expect(throws: CoreError.nonRigidMatrix) { try UnitQuaternion(matrix: Matrix3(-1, 0, 0, 0, 1, 0, 0, 0, 1), tolerance: tolerance) }
    }

    @Test func bodyAndWorldRatesHaveExplicitComposition() throws {
        let orientation = try UnitQuaternion(axis: .unitX, angle: .pi / 2)
        let angular = try Vector3(0, 0, 2)
        let integrator: any RotationIntegrating = orientation
        let body = try integrator.integratingBodyAngularVelocity(angular, timeStep: 0.1)
        let world = try integrator.integratingWorldAngularVelocity(angular, timeStep: 0.1)
        #expect(try body.matrix().subtracting(world.matrix()).maximumMagnitude > 0.1)
        let rate = try integrator.bodyRate(for: angular)
        let dt = 1e-6
        let later = try integrator.integratingBodyAngularVelocity(angular, timeStep: dt)
        #expect(abs((later.w - orientation.w) / dt - rate.w) < 2e-6)
        #expect(abs((later.x - orientation.x) / dt - rate.x) < 2e-6)
        #expect(abs((later.y - orientation.y) / dt - rate.y) < 2e-6)
        #expect(abs((later.z - orientation.z) / dt - rate.z) < 2e-6)
        let signEquivalent = try orientation.negated().integratingBodyAngularVelocity(angular, timeStep: 0.1)
        #expect(try body.matrix().subtracting(signEquivalent.matrix()).maximumMagnitude < 1e-14)
        #expect(throws: CoreError.invalidTimeStep) { try integrator.integratingBodyAngularVelocity(angular, timeStep: -1) }
        var accumulated = UnitQuaternion.identity
        for _ in 0..<10000 { accumulated = try accumulated.integratingBodyAngularVelocity(.unitZ, timeStep: 0.001) }
        let expected = try UnitQuaternion(axis: .unitZ, angle: 10)
        #expect(try accumulated.matrix().subtracting(expected.matrix()).maximumMagnitude < 1e-11)
    }
}
