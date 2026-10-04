public struct NonlinearStabilityPoint: Sendable {
    public enum Classification: Sendable { case positive, neutral, negative }
    public let position: [Double]
    public let parameter: Double
    public let energy: Double
    public let physicalGradient: [Double]
    public let generalizedReaction: [Double]
    public let rowMultipliers: [Double]
    public let originalForceResidual: [Double]
    public let originalConstraintResidual: [Double]
    public let originalArcResidual: Double
    /// Ascending eigenvalues; mode-major physical full-coordinate modes have unit actual mass norm.
    public let stiffnessEigenvalues: [Double]
    public let modes: [Double]
    public let reducedMass: [Double]
    public let reducedStiffness: [Double]
    public let maximumProjectedResidual: Double
    public let maximumMassError: Double
    public let maximumDerivativeError: Double
    public let maximumInertialError: Double
    public let classification: Classification
    public let work: NumericalWork
}
