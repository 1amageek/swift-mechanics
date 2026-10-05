public struct GyroscopicRotorEvaluator: GyroscopicRotorEvaluating {
    public init() {}
    public func evaluate(rotor r: GyroscopicRotor, axis a: Vector3, carrierSpeed omega: Vector3,
                         carrierAcceleration alpha: Vector3, spinSpeed: Double, spinAcceleration: Double,
                         work: inout LoadWork) throws(LoadError) -> GyroscopicRotorResponse {
        try work.reserve(scalars: 64); try work.charge(80)
        guard spinSpeed.isFinite, spinAcceleration.isFinite else { throw .invalidInput }
        let axisNorm = try core { () throws(CoreError) in try a.magnitude() }
        guard abs(axisNorm - 1) <= 1e-12 else { throw .invalidShape }
        guard abs(spinSpeed) <= r.maximumSpeed, abs(spinAcceleration) <= r.maximumAcceleration,
              try core({ () throws(CoreError) in try omega.magnitude() }) <= r.maximumSpeed,
              try core({ () throws(CoreError) in try alpha.magnitude() }) <= r.maximumAcceleration else { throw .outsideDomain }
        // Decompose the total angular velocity for nonnegative physical kinetic storage.
        let axialSpeed = try core { () throws(CoreError) in try omega.dot(a) }
        let axialAcceleration = try core { () throws(CoreError) in try alpha.dot(a) }
        let totalAxial = try finite(axialSpeed + spinSpeed)
        let transverse = try core { () throws(CoreError) in try omega.subtracting(a.scaled(by: axialSpeed)) }
        let transverseAcceleration = try core { () throws(CoreError) in try alpha.subtracting(a.scaled(by: axialAcceleration)) }
        let inertiaOmega = try inertia(omega, a, r)
        let inertiaAlpha = try inertia(alpha, a, r)
        let precession = try core { () throws(CoreError) in try omega.cross(a).scaled(by: r.polarInertia * spinSpeed) }
        let required = try core { () throws(CoreError) in
            try inertiaAlpha.adding(omega.cross(inertiaOmega))
                .adding(a.scaled(by: r.polarInertia * spinAcceleration)).adding(precession)
        }
        let motorScalar = try finite(r.polarInertia * (axialAcceleration + spinAcceleration))
        let motor = try core { () throws(CoreError) in try a.scaled(by: motorScalar) }
        let bearing = try core { () throws(CoreError) in try required.subtracting(motor) }
        let kinetic = try finite(0.5 * r.transverseInertia * core({ () throws(CoreError) in try transverse.dot(transverse) })
                                + 0.5 * r.polarInertia * totalAxial * totalAxial)
        let rate = try finite(r.transverseInertia * core({ () throws(CoreError) in try transverse.dot(transverseAcceleration) })
                             + r.polarInertia * totalAxial * (axialAcceleration + spinAcceleration))
        let carrierPower = try core { () throws(CoreError) in try required.dot(omega) }
        let relativePower = try finite(motorScalar * spinSpeed)
        let residual = try finite(carrierPower + relativePower - rate)
        try work.charge(0)
        return GyroscopicRotorResponse(requiredTorque: required, motorTorque: motor, bearingTorque: bearing,
            motorReaction: try core { () throws(CoreError) in try motor.scaled(by: -1) }, bearingReaction: try core { () throws(CoreError) in try bearing.scaled(by: -1) },
            kineticEnergy: kinetic, energyRate: rate, carrierPower: carrierPower,
            relativeMotorPower: relativePower, powerResidual: residual)
    }
    private func inertia(_ v: Vector3, _ a: Vector3, _ r: GyroscopicRotor) throws(LoadError) -> Vector3 {
        try core { () throws(CoreError) in try v.scaled(by: r.transverseInertia)
            .adding(a.scaled(by: (r.polarInertia - r.transverseInertia) * v.dot(a))) }
    }
    private func core<T>(_ body: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    private func finite(_ x: Double) throws(LoadError) -> Double {
        guard x.isFinite else { throw .nonFiniteResult }; return x
    }
}
