import MechanicsNumerics
import MechanicsContactLaws
import MechanicsCollision
public protocol SurfaceContactForceMapping: Sendable {
    func initialHistory(_ witness: SurfaceContactWitness, key: String, pair: ContactLawPair, policy: DeformingContactPolicy,
                        work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> ContactHistory
    func evaluate(_ witness: SurfaceContactWitness, current: DeformingSurfaceSnapshot, currentObstacle: CollisionProxy?, key: String, pair: ContactLawPair, accepted: ContactHistory,
                  timeStep: Double, policy: DeformingContactPolicy, lawPolicy: ContactAcceptancePolicy,
                  work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceForceTrial
}
