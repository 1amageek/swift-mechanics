import MechanicsConstraints
public struct ConstraintTangent: Sendable {
    public let evaluation: ConstraintEvaluation
    public let values: [Double]
    public let normalizedJacobian: [Double]
    public let physicalJacobian: [Double]
    public let timeDerivative: [Double]
    public let accelerationBias: [Double]
}
