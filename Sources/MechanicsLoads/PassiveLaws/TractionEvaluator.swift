import MechanicsCore
import MechanicsModel
public struct TractionEvaluator: TractionEvaluating {
    public init() {}
    public func equivalent(body: EntityID, frame: EntityID, samples: [TractionSample], referencePoint: Vector3,
                           follower: Bool = false, work: inout LoadWork) throws(LoadError) -> EquivalentLoad {
        if follower {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Follower geometry/tangent is not implemented. This callable load path must fail until evolving geometry and consistent derivatives have behavioral evidence.
            throw .unsupportedDomain
        }
        guard !samples.isEmpty, body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        var force = Vector3.zero, torque = Vector3.zero
        for sample in samples {
            try work.charge(1)
            let sampleForce = try loadCore { () throws(CoreError) in try sample.traction.scaled(by: sample.area) }
            force = try loadCore { () throws(CoreError) in try force.adding(sampleForce) }
            torque = try loadCore { () throws(CoreError) in try torque.adding(sample.point.subtracting(referencePoint).cross(sampleForce)) }
        }
        // Fixed externally declared traction has no inferred conservative energy.
        return EquivalentLoad(body: body, frame: frame, referencePoint: referencePoint,
            wrench: SpatialWrench(torque: torque, force: force), potentialEnergy: nil, explicitPotentialTimeDerivative: nil)
    }
}
