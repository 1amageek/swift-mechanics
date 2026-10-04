import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct UnitsTests {
    @Test func mixedUnitsAndAbsoluteTemperature() throws {
        let converter: any UnitConverting = SIUnitConverter()
        #expect(abs(try converter.convert(12, from: SIUnits.inch, to: SIUnits.metre) - 0.3048) < 1e-15)
        #expect(abs(try converter.convert(2500, from: SIUnits.millimetre, to: SIUnits.metre) - 2.5) < 1e-15)
        #expect(abs(try converter.convert(180, from: SIUnits.degree, to: SIUnits.radian) - Double.pi) < 1e-15)
        #expect(abs(try converter.convert(1000, from: SIUnits.millisecond, to: SIUnits.second) - 1) < 1e-15)
        #expect(abs(try converter.convert(100, from: SIUnits.celsius, to: SIUnits.kelvin) - 373.15) < 1e-12)
        #expect(abs(try converter.convert(273.15, from: SIUnits.kelvin, to: SIUnits.celsius)) < 1e-12)
        #expect(try converter.convert(24, from: SIUnits.volt, to: SIUnits.volt) == 24)
    }

    @Test func incompatibleAndUnrepresentableConversionFails() throws {
        let converter = SIUnitConverter()
        #expect(throws: CoreError.dimensionMismatch) { try converter.convert(1, from: SIUnits.metre, to: SIUnits.second) }
        #expect(throws: CoreError.nonFiniteInput) { try converter.convert(.infinity, from: SIUnits.metre, to: SIUnits.metre) }
        #expect(throws: CoreError.invalidUnitScale) { try UnitDefinition(symbol: "bad", dimension: .length, scale: 0) }
        #expect(throws: CoreError.invalidUnitOffset) { try UnitDefinition(symbol: "bad", dimension: .length, scale: 1, offset: 1) }
        let huge = try UnitDefinition(symbol: "huge", dimension: .length, scale: .greatestFiniteMagnitude)
        #expect(throws: CoreError.nonFiniteResult) { try converter.convert(2, from: huge, to: SIUnits.metre) }
    }

    @Test func dimensionsComposeWithCheckedExponents() throws {
        let velocity = try PhysicalDimension.length.multiplied(by: PhysicalDimension(time: -1))
        #expect(velocity == .velocity)
        let force = try PhysicalDimension.mass.multiplied(by: .acceleration)
        #expect(force == .force)
        #expect(try PhysicalDimension.force.multiplied(by: .length) == .energy)
        #expect(PhysicalDimension.angle != .dimensionless)
        #expect(throws: CoreError.dimensionExponentOverflow) {
            try PhysicalDimension(length: 127).multiplied(by: .length)
        }
    }
}
