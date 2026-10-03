import MechanicsCore
import MechanicsModel
public protocol GravityEvaluating: Sendable {
    func point(_ field: AffineGravity, body: EntityID, sample: GravitySample, work: inout LoadWork) throws(LoadError) -> GravityResponse
    func distributed(_ field: AffineGravity, body: EntityID, samples: [GravitySample], referencePoint: Vector3,
                     work: inout LoadWork) throws(LoadError) -> EquivalentLoad
}
