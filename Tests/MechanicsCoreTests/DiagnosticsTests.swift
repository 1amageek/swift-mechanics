import MechanicsCore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct DiagnosticsTests {
    @Test func toleranceUsesIndependentAbsoluteAndRelativeScales() throws {
        let tolerance = try NumericalTolerance(absolute: 0.01, relative: 0.001)
        #expect(try tolerance.contains(error: -0.05, scale: 100))
        #expect(try !tolerance.contains(error: 0.12, scale: 100))
        #expect(try tolerance.contains(error: 0.009, scale: 0))
        #expect(throws: CoreError.invalidTolerance) { try NumericalTolerance(absolute: -1, relative: 0) }
        #expect(throws: CoreError.invalidTolerance) { try tolerance.contains(error: .nan, scale: 1) }
        #expect(throws: CoreError.invalidTolerance) { try tolerance.contains(error: 0, scale: -1) }
        let excessive = try NumericalTolerance(absolute: .greatestFiniteMagnitude, relative: 1)
        #expect(throws: CoreError.nonFiniteResult) { try excessive.contains(error: 1, scale: .greatestFiniteMagnitude) }
    }
}
