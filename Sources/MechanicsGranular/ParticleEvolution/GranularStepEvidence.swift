public struct GranularStepEvidence: Sendable {
    public let maximumLinearImpulseResidual: Double, maximumAngularImpulseResidual: Double
    public let kineticEnergyChange: Double, particleMidpointWork: Double, originalWorkResidual: Double
    public let contactStoredEnergy: Double, constitutiveDissipationEnergy: Double
    public let prescribedBoundaryWork: Double
    internal init(linear: Double, angular: Double, kineticChange: Double, work: Double, workResidual: Double, stored: Double, dissipation: Double, boundaryWork: Double) {
        maximumLinearImpulseResidual=linear; maximumAngularImpulseResidual=angular
        kineticEnergyChange=kineticChange; particleMidpointWork=work; originalWorkResidual=workResidual
        contactStoredEnergy=stored; constitutiveDissipationEnergy=dissipation; prescribedBoundaryWork=boundaryWork
    }
}
