/// Query-only force proposal. This value does not advance rigid or flexible state.
public final class AttachmentForceProposal: Sendable {
    public let query: RigidMaterialAttachmentQuery
    public let multipliers: [Double]
    public let nodalForces: [Vector3]
    public let rigidLoads: [AttachmentRigidLoad]
    public let generalizedEfforts: [Double]
    public let nodalPower: Double
    public let rigidPower: Double
    public let prescribedRigidPower: Double
    public let multiplierPower: Double
    public let forceResidual: Double
    public let momentResidual: Double
    public let powerResidual: Double
    public let numericalWork: NumericalWork
    public let policy: AttachmentPolicy
    public let surfacePolicy: DeformingContactPolicy

    internal init(query: RigidMaterialAttachmentQuery, multipliers: [Double], forces: [Vector3],
                  loads: [AttachmentRigidLoad], efforts: [Double], nodalPower: Double, rigidPower: Double,
                  prescribedPower: Double, multiplierPower: Double, forceResidual: Double,
                  momentResidual: Double, powerResidual: Double, policy: AttachmentPolicy,
                  surfacePolicy: DeformingContactPolicy, work: NumericalWork) {
        self.query = query; self.multipliers = multipliers; self.nodalForces = forces
        self.rigidLoads = loads; self.generalizedEfforts = efforts; self.nodalPower = nodalPower
        self.rigidPower = rigidPower; self.prescribedRigidPower = prescribedPower
        self.multiplierPower = multiplierPower; self.forceResidual = forceResidual
        self.momentResidual = momentResidual; self.powerResidual = powerResidual; self.numericalWork = work
        self.policy = policy; self.surfacePolicy = surfacePolicy
    }
}
