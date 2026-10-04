import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct QuaternionRestorationTests {
    @Test func actualConstructorsRestoreEveryComponentBit() throws {
        let axes = [Vector3.unitX, .unitY, .unitZ, try Vector3(1, 2, 3).normalized()]
        let angles = [0.0, 1e-12, 0.1, 1.2, Double.pi, 7.3]
        var sources = [
            try UnitQuaternion(w: -1, x: -0.0, y: 0.0, z: -0.0),
            try UnitQuaternion(w: Double.greatestFiniteMagnitude, x: 1, y: -1, z: 2),
            try UnitQuaternion(w: Double.leastNonzeroMagnitude, x: 0, y: 0, z: 0)
        ]
        for axis in axes {
            for angle in angles {
                let original = try UnitQuaternion(axis: axis, angle: angle)
                sources.append(original)
                sources.append(original.negated())
                sources.append(original.conjugated())
                sources.append(try original.multiplied(by: sources[0]))
                sources.append(try original.integratingWorldAngularVelocity(axis, timeStep: 0.03125))
            }
        }
        for source in sources {
            let restored = try UnitQuaternion(unitW: source.w, x: source.x, y: source.y, z: source.z)
            #expect(restored.w.bitPattern == source.w.bitPattern)
            #expect(restored.x.bitPattern == source.x.bitPattern)
            #expect(restored.y.bitPattern == source.y.bitPattern)
            #expect(restored.z.bitPattern == source.z.bitPattern)
            #expect(try restored.matrix() == source.matrix())
        }
    }

    @Test func restorationRejectsNormalizationAndInvalidValues() throws {
        for components in [(0.0, 0.0), (2.0, 0.0), (0.5, 0.0), (1.0, 1e-6),
                           (Double.greatestFiniteMagnitude, 0.0), (Double.leastNonzeroMagnitude, 0.0)] {
            #expect(throws: CoreError.nonUnitQuaternion) {
                try UnitQuaternion(unitW: components.0, x: components.1, y: 0, z: 0)
            }
        }
        for value in [Double.nan, .infinity, -.infinity] {
            #expect(throws: CoreError.nonFiniteInput) { try UnitQuaternion(unitW: value, x: 0, y: 0, z: 0) }
            #expect(throws: CoreError.nonFiniteInput) { try UnitQuaternion(unitW: 1, x: value, y: 0, z: 0) }
        }
        let accepted = try UnitQuaternion(unitW: 1 + 4 * Double.ulpOfOne, x: -0.0, y: 0, z: 0)
        #expect(accepted.w.bitPattern == (1 + 4 * Double.ulpOfOne).bitPattern)
        #expect(accepted.x.bitPattern == (-0.0 as Double).bitPattern)
        #expect(throws: CoreError.nonUnitQuaternion) {
            try UnitQuaternion(unitW: 1 + 32 * Double.ulpOfOne, x: 0, y: 0, z: 0)
        }
        let normalizing = try UnitQuaternion(w: 2, x: 0, y: 0, z: 0)
        #expect(normalizing == .identity)
    }
}
