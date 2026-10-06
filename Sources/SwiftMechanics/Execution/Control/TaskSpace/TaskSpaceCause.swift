public enum TaskSpaceCause: Error, Sendable {
    case invalidInput, invalidShape, capacityExceeded, staleSource, frameMismatch, referencePointMismatch
    case unsupportedDomain, incompatibleForceMotion, cancelled, nonFiniteResult
    case singularTask(rank: Int, rows: Int)
    case taskResidualRejected(value: Double, threshold: Double)
    case secondaryLeakRejected(value: Double, threshold: Double)
    case powerResidualRejected(value: Double, threshold: Double)
    case generalizedReplayRejected(value: Double, threshold: Double)
    case invalidSupplierLedger, invalidSupplierOutput
    case numerical(NumericalError)
    case dynamics(DynamicsError)
    case joints(JointError)
    case core(CoreError)
}
