public struct ModalReducedStep: Sendable {
    public let state: ModalReducedState
    /// Full original layout including zero increments at fixed coordinates.
    public let displacement: [Double]
    public let velocity: [Double]
    public let interfaceDisplacement: [Double]
    public let interfaceVelocity: [Double]
    /// Original unfixed-coordinate residual in physical conjugate effort units.
    public let fullResidual: [Double]
    public let maximumNormalizedFullResidual: Double
    public let maximumNormalizedProjectedResidual: Double
    public let maximumReferenceDisplacementError: Double?
    public let interfacePower: Double
    public let reducedInterfacePower: Double
    public let normalizedInterfacePowerError: Double
    public let work: NumericalWork
}
