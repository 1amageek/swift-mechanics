internal enum RetimingArithmetic {
    static let speedMaximum = 15.0 / 8
    static let accelerationMaximum = 10.0 / 3.0.squareRoot()

    static func finite(_ value: Double) throws(RetimingError) -> Double {
        guard value.isFinite else { throw .nonFiniteArithmetic }; return value
    }
    static func product(_ a: Int, _ b: Int) throws(RetimingError) -> Int {
        let (value, overflow) = a.multipliedReportingOverflow(by: b)
        guard a >= 0, b >= 0, !overflow else { throw .capacityExceeded }; return value
    }
    static func sum(_ a: Int, _ b: Int) throws(RetimingError) -> Int {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !overflow else { throw .capacityExceeded }; return value
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(RetimingError) {
        do throws(NumericalError) { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func reserve(_ count: Int, _ work: inout NumericalWork) throws(RetimingError) {
        do throws(NumericalError) { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func checkpoint(_ policy: RetimingPolicy) throws(RetimingError) {
        guard !policy.isCancelled(), !policy.dynamicsAdmission.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    /// Conservative simultaneous scalar accounting, including retained source/path/result and local kinematic storage.
    static func storage(bodies: Int, joints: Int, coordinates: Int, segments: Int) throws(RetimingError) -> Int {
        var value = try product(1024, bodies)
        value = try sum(value, product(256, joints))
        value = try sum(value, product(32, product(bodies, coordinates)))
        value = try sum(value, product(16, product(coordinates, coordinates)))
        value = try sum(value, product(128, coordinates))
        value = try sum(value, product(24, product(segments, coordinates)))
        return try sum(value, product(8, segments))
    }
    static func lowerDuration(amplitude: Double, allowance: Double, quadratic: Bool,
                              segment: Int, coordinate: Int) throws(RetimingError) -> Double {
        guard amplitude > 0 else { return 0 }
        guard allowance.isFinite, allowance > 0 else { throw .infeasibleMotion(segment: segment, coordinate: coordinate) }
        if quadratic {
            // Square roots avoid overflowing amplitude/allowance when a representable duration exists.
            let value = try finite(amplitude.squareRoot() / allowance.squareRoot())
            guard value > 0 else { throw .nonFiniteArithmetic }; return value
        }
        let value = try finite(amplitude / allowance)
        guard value > 0 else { throw .nonFiniteArithmetic }; return value
    }
    static func envelope(_ amplitude: Double, factor: Double) throws(RetimingError) -> Double {
        if amplitude == 0 { return 0 }
        guard amplitude > 0 else { throw .nonFiniteArithmetic }
        return try finite((try finite(amplitude * factor)).nextUp)
    }
    static func scaledAmplitude(_ coefficient: Double, maximum: Double, inverse: Double, quadratic: Bool) throws(RetimingError) -> Double {
        if coefficient == 0 { return 0 }
        var value = try finite(abs(coefficient) * maximum)
        value = try finite(value * inverse)
        guard value > 0 else { throw .nonFiniteArithmetic }
        if quadratic {
            value = try finite(value * inverse)
            guard value > 0 else { throw .nonFiniteArithmetic }
        }
        return value
    }
    static func symmetric(radius: Double, center: Double = 0) throws(RetimingError) -> RetimingInterval {
        if radius == 0 { return RetimingInterval(uncheckedLower: center, upper: center) }
        return RetimingInterval(uncheckedLower: try finite((center - radius).nextDown),
                                upper: try finite((center + radius).nextUp))
    }
    static func contains(_ outer: RetimingInterval, _ inner: RetimingInterval) -> Bool {
        outer.contains(inner.lower) && outer.contains(inner.upper)
    }
}
