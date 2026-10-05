public struct SphereAddedInertiaEvaluator: SphereAddedInertiaEvaluating {
    public init() {}
    public func evaluate(law: SphereAddedInertiaLaw, bodyVelocity: Vector3, bodyAcceleration: Vector3,
                         fluidVelocity: Vector3, fluidAcceleration: Vector3, work: inout LoadWork) throws(LoadError) -> SphereAddedInertiaResponse {
        try work.reserve(scalars: 64); try work.charge(80)
        guard try core({ () throws(CoreError) in try bodyVelocity.magnitude() }) <= law.maximumSpeed,
              try core({ () throws(CoreError) in try fluidVelocity.magnitude() }) <= law.maximumSpeed,
              try core({ () throws(CoreError) in try bodyAcceleration.magnitude() }) <= law.maximumAcceleration,
              try core({ () throws(CoreError) in try fluidAcceleration.magnitude() }) <= law.maximumAcceleration else { throw .outsideDomain }
        let relativeVelocity = try core { () throws(CoreError) in try bodyVelocity.subtracting(fluidVelocity) }
        let relativeAcceleration = try core { () throws(CoreError) in try bodyAcceleration.subtracting(fluidAcceleration) }
        let addedForce = try core { () throws(CoreError) in try relativeAcceleration.scaled(by: -law.addedMass) }
        let pressureForce = try core { () throws(CoreError) in try fluidAcceleration.scaled(by: law.displacedMass) }
        let total = try core { () throws(CoreError) in try addedForce.adding(pressureForce) }
        let relativeMomentum = try core { () throws(CoreError) in try relativeVelocity.scaled(by: law.addedMass) }
        let energy = try finite(0.5 * core({ () throws(CoreError) in try relativeMomentum.dot(relativeVelocity) }))
        let rate = try core { () throws(CoreError) in try relativeMomentum.dot(relativeAcceleration) }
        let bodyPower = try core { () throws(CoreError) in try total.dot(bodyVelocity) }
        let mediumPower = try core { () throws(CoreError) in try addedForce.dot(fluidVelocity) }
        let pressurePower = try core { () throws(CoreError) in try pressureForce.dot(bodyVelocity) }
        let massMatrix = try core { () throws(CoreError) in try Matrix3.identity.scaled(by: law.addedMass) }
        let bodyDerivative = try core { () throws(CoreError) in try massMatrix.scaled(by: -1) }
        let fluidDerivative = try core { () throws(CoreError) in try Matrix3.identity.scaled(by: law.displacedMass + law.addedMass) }
        let residual = try finite(bodyPower + rate - mediumPower - pressurePower)
        try work.charge(0)
        return SphereAddedInertiaResponse(addedMassMatrix: massMatrix, bodyAccelerationDerivative: bodyDerivative,
            fluidAccelerationDerivative: fluidDerivative, addedInertiaForce: addedForce, pressureGradientForce: pressureForce,
            totalForce: total, relativeKineticEnergy: energy, relativeKineticEnergyRate: rate,
            bodyPower: bodyPower, prescribedMediumPower: mediumPower, prescribedPressurePower: pressurePower, powerResidual: residual)
    }
    private func core<T>(_ body: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
