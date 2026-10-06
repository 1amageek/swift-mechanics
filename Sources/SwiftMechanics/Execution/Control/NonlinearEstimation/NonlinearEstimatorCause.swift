public indirect enum NonlinearEstimatorCause: Error, Sendable {
    case invalidInput
    case invalidPolicy
    case unsupportedModel
    case outsidePhysicalDomain
    case sourceMismatch
    case physicalEvidenceRejected
    case derivativeEvidenceRejected
    case invalidCovariance
    case covarianceMagnitudeExceeded
    case nonpositiveInnovation
    case innovationRejected(normalizedSquared: Double, limit: Double)
    case observationTimeMismatch(measured: Double, target: Double)
    case delayedObservationUnsupported(measured: Double, target: Double)
    case deliveryTimeMismatch
    case observationSequenceMismatch
    case capacityExceeded
    case cancelled
    case integerOverflow
    case numerical(NumericalError)
    case linear(NumericalError, failedSupplierWorkUnavailable: Bool)
    case compilation(CompilationFailure)
    case joints(JointError)
    case loads(LoadError)
    case dynamics(DynamicsError)
    case derivatives(DerivativeError)
    case observations(ObservationError)
    case invalidSupplierOutput
}
