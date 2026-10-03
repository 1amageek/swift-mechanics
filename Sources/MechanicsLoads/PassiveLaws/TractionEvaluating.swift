import MechanicsCore
import MechanicsModel
public protocol TractionEvaluating: Sendable {
    func equivalent(body: EntityID, frame: EntityID, samples: [TractionSample], referencePoint: Vector3,
                    follower: Bool, work: inout LoadWork) throws(LoadError) -> EquivalentLoad
}
