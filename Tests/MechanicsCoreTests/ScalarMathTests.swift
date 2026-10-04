@testable import SwiftMechanics
import Testing
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

@Suite(.timeLimit(.minutes(1)))
struct ScalarMathTests {
    @Test func trigonometryPreservesPlatformResultsAndSignedZero() {
        for value in [0.0, -0.0, 0.7, -0.7, Double.pi, 1e308, Double.nan, .infinity, -.infinity] {
            let actualSine = ScalarMath.sine(value), expectedSine = sin(value)
            let actualCosine = ScalarMath.cosine(value), expectedCosine = cos(value)
            if expectedSine.isNaN { #expect(actualSine.isNaN) }
            else { #expect(actualSine.bitPattern == expectedSine.bitPattern) }
            if expectedCosine.isNaN { #expect(actualCosine.isNaN) }
            else { #expect(actualCosine.bitPattern == expectedCosine.bitPattern) }
        }
        #expect(ScalarMath.sine(-0.0).sign == .minus)
        #expect(ScalarMath.cosine(0) == 1)
        #expect(abs(ScalarMath.sine(.pi / 6) - 0.5) < 1e-14)
    }

    @Test func anglePreservesArgumentOrderQuadrantsAndExceptionalValues() {
        let pairs: [(Double, Double)] = [
            (0, 1), (-0.0, 1), (0, -1), (-0.0, -1),
            (1, 0), (-1, 0), (1, 1), (1, -1), (-1, -1), (-1, 1),
            (.infinity, .infinity), (-.infinity, -.infinity), (.nan, 1), (1, .nan)
        ]
        for (y, x) in pairs {
            let actual = ScalarMath.angle(y: y, x: x), expected = atan2(y, x)
            if expected.isNaN { #expect(actual.isNaN) }
            else { #expect(actual.bitPattern == expected.bitPattern) }
        }
        #expect(ScalarMath.angle(y: 0, x: -1) == .pi)
        #expect(ScalarMath.angle(y: -0.0, x: -1) == -.pi)
        #expect(ScalarMath.angle(y: 1, x: 0) == .pi / 2)
    }

    @Test func normPreservesScaledExtremesAndNonfiniteSemantics() {
        let pairs: [(Double, Double)] = [
            (3, 4), (-3, -4), (0, -0.0), (1e308, 1e308), (1e-308, 1e-308),
            (.leastNonzeroMagnitude, 0), (.greatestFiniteMagnitude, .greatestFiniteMagnitude),
            (.infinity, 1), (.infinity, .nan), (.nan, 1)
        ]
        for (x, y) in pairs {
            let actual = ScalarMath.norm(x, y), expected = hypot(x, y)
            if expected.isNaN { #expect(actual.isNaN) }
            else { #expect(actual.bitPattern == expected.bitPattern) }
        }
        #expect(ScalarMath.norm(3, 4) == 5)
        #expect(ScalarMath.norm(0, -0.0).sign == .plus)
        #expect(ScalarMath.norm(1e308, 1e308).isFinite)
        #expect(ScalarMath.norm(1e-308, 1e-308) > 0)
    }

    @Test func productionConsumersRetainCheckedGeometryAndPhaseSemantics() throws {
        let large = try Vector3(1e308, 1e308, 0).magnitude()
        #expect(large.bitPattern == hypot(hypot(1e308, 1e308), 0).bitPattern)
        #expect(try Vector3(.leastNonzeroMagnitude, 0, 0).magnitude() == .leastNonzeroMagnitude)
        #expect(throws: CoreError.nonFiniteResult) {
            try Vector3(.greatestFiniteMagnitude, .greatestFiniteMagnitude, 0).magnitude()
        }
        #expect(throws: CoreError.nonFiniteInput) { try Vector3(.infinity, 0, 0) }

        let angle = 1.4, quaternion = try UnitQuaternion(axis: .unitZ, angle: angle)
        #expect(abs(quaternion.w - cos(angle / 2)) < 1e-15)
        #expect(abs(quaternion.z - sin(angle / 2)) < 1e-15)
        #expect(abs(try quaternion.rotationVector().z - angle) < 1e-14)
        #expect(throws: CoreError.nonFiniteInput) { try UnitQuaternion(axis: .unitZ, angle: .nan) }

        let positive = try StructuralComplex(real: -1, imaginary: 0)
        let negative = try StructuralComplex(real: -1, imaginary: -0.0)
        #expect(positive.phaseRadians == Double.pi && negative.phaseRadians == -Double.pi)
        #expect(try StructuralComplex(real: 0, imaginary: -0.0).phaseRadians == nil)
        #expect(try StructuralComplex(real: 1e308, imaginary: 1e308).amplitude == hypot(1e308, 1e308))
        do throws(StructuralError) {
            _ = try StructuralComplex(real: .greatestFiniteMagnitude, imaginary: .greatestFiniteMagnitude)
            Issue.record("An overflowing structural norm must fail.")
        } catch {
            guard case .nonFiniteResult = error else { throw error }
        }
    }
}
