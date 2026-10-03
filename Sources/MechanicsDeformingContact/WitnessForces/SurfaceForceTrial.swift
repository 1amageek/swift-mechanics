import MechanicsCore
import MechanicsContactLaws
public final class SurfaceForceTrial: Sendable {
    public let witness: SurfaceContactWitness
    public let response: ContactResponse
    public let nodalForces: [Vector3]
    public let obstacleReaction: SpatialWrench
    public let relativeVelocity: Vector3
    public let mappedPower: Double
    public let forceResidual: Double, momentResidual: Double, powerResidual: Double
    internal init(witness: SurfaceContactWitness, response: ContactResponse, forces: [Vector3], reaction: SpatialWrench,
                  relativeVelocity: Vector3, mappedPower: Double, forceResidual: Double, momentResidual: Double, powerResidual: Double) {
        self.witness=witness; self.response=response; nodalForces=forces; obstacleReaction=reaction
        self.relativeVelocity=relativeVelocity; self.mappedPower=mappedPower; self.forceResidual=forceResidual; self.momentResidual=momentResidual; self.powerResidual=powerResidual
    }
}
