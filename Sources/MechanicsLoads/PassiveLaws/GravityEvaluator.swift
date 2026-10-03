import MechanicsCore
import MechanicsModel
public struct GravityEvaluator: GravityEvaluating {
    public init() {}
    public func point(_ field: AffineGravity, body: EntityID, sample: GravitySample, work: inout LoadWork) throws(LoadError) -> GravityResponse {
        try work.charge(1)
        let gradientImage = try loadCore { () throws(CoreError) in try field.gradient.applying(to: sample.point) }
        let force = try loadCore { () throws(CoreError) in try field.accelerationAtOrigin.adding(gradientImage).scaled(by: sample.mass) }
        let potential = try loadFinite(-sample.mass * loadCore { () throws(CoreError) in try field.accelerationAtOrigin.dot(sample.point) + sample.point.dot(gradientImage) / 2 })
        let timeDerivative = try loadFinite(-sample.mass * loadCore { () throws(CoreError) in try field.uniformTimeDerivative.dot(sample.point) })
        return try GravityResponse(load: FramedPointLoad(body: body, frame: field.frame, point: sample.point,
            forces: ForceParts(conservative: force), potentialEnergy: potential),
            forcePositionDerivative: loadCore { () throws(CoreError) in try field.gradient.scaled(by: sample.mass) }, explicitPotentialTimeDerivative: timeDerivative)
    }
    public func distributed(_ field: AffineGravity, body: EntityID, samples: [GravitySample], referencePoint: Vector3,
                            work: inout LoadWork) throws(LoadError) -> EquivalentLoad {
        guard !samples.isEmpty else { throw .invalidShape }
        var force = Vector3.zero, torque = Vector3.zero, energy = 0.0, explicitRate = 0.0
        for sample in samples {
            let response = try point(field, body: body, sample: sample, work: &work)
            let wrench = try response.load.wrench(about: referencePoint)
            force = try loadCore { () throws(CoreError) in try force.adding(wrench.force) }; torque = try loadCore { () throws(CoreError) in try torque.adding(wrench.torque) }
            // Point gravity always supplies potential energy by its public contract.
            guard let sampleEnergy = response.load.potentialEnergy else { throw .missingEnergy }
            energy = try loadFinite(energy + sampleEnergy)
            explicitRate = try loadFinite(explicitRate + response.explicitPotentialTimeDerivative)
        }
        return EquivalentLoad(body: body, frame: field.frame, referencePoint: referencePoint,
            wrench: SpatialWrench(torque: torque, force: force), potentialEnergy: energy, explicitPotentialTimeDerivative: explicitRate)
    }
}
