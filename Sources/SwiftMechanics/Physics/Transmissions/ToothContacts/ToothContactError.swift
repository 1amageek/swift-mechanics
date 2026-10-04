public enum ToothContactError: Error, Sendable {
    case invalidInput, unsupportedDomain, staleSource, invalidSupplierOutput, capacityExceeded, cancelled, nonFiniteResult
    case invalidSupplierLedger(failedSupplierWorkUnavailable: Bool)
    case originalResidual(value: Double, threshold: Double)
    case energyDefect(value: Double, maximum: Double)
    case collision(CollisionError)
    case contact(ContactLawError)
    case current(ContactCurrentError)
    case materialChartSingularity
    case dynamics(DynamicsError)
    case numerical(NumericalError)
    case joint(JointError)
    case core(CoreError)
    case unexpectedKinematicsFailure
}
