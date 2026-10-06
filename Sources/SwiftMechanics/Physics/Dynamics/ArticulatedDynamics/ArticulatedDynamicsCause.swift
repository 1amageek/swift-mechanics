public enum ArticulatedDynamicsCause: Error, Sendable {
    case invalidInput, invalidShape, capacityExceeded, unsupportedDomain, invalidTopology, sourceMismatch, frameMismatch
    case velocityMismatch, nonFiniteResult, cancelled
    case singularJoint(joint: EntityID, normalizedPivot: Double, threshold: Double)
    case originalResidualRejected(value: Double, threshold: Double)
    case originalPowerRejected(value: Double, threshold: Double)
    case numerical(NumericalError)
    case dynamics(DynamicsError)
    case core(CoreError)
    case joints(JointError)
    case loads(LoadError)
}
