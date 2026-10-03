import MechanicsCompiler
import MechanicsModel
import MechanicsDynamics
import MechanicsJoints

public final class DetachedLeafTransition: Sendable {
    public let source:CompiledKinematicState
    public let sourceSnapshot:KinematicSnapshot
    public let target:CompiledMechanicalModel
    public let physical:KinematicState
    public let removedJoint:EntityID
    public let freeConnector:EntityID
    public let body:EntityID
    public let sourceEnergy:MechanicalEnergy
    public let targetEnergy:MechanicalEnergy
    internal init(source:CompiledKinematicState,snapshot:KinematicSnapshot,target:CompiledMechanicalModel,physical:KinematicState,removed:EntityID,connector:EntityID,body:EntityID,
                  sourceEnergy:MechanicalEnergy,targetEnergy:MechanicalEnergy) {
        self.source=source;sourceSnapshot=snapshot;self.target=target;self.physical=physical;removedJoint=removed;freeConnector=connector;self.body=body
        self.sourceEnergy=sourceEnergy;self.targetEnergy=targetEnergy
    }
}
