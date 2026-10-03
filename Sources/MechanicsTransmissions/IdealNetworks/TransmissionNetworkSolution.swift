import MechanicsConstraints

public struct TransmissionNetworkSolution: Sendable {
    public let assembly: ConstraintAssemblySolution
    public let originalPhysicalPhaseResidual: Double
}
