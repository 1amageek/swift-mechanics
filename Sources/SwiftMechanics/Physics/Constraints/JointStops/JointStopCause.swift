public enum JointStopCause: Error, Sendable {
    case invalidInput, invalidShape, capacityExceeded, staleSource, unknownJoint, unitMismatch, unsupportedDomain
    case nonboundary, ambiguousBoundary, nonapproaching, singularNormalMass, nonFiniteResult, cancelled
    case invalidSupplierLedger, invalidSupplierOutput
    case normalRateRejected(value: Double, threshold: Double)
    case momentumRejected(value: Double, threshold: Double)
    case workRejected(value: Double, threshold: Double)
    case energyRejected(value: Double, threshold: Double)
    case numerical(NumericalError), compilation(CompilationFailure), observation(ObservationError)
    case constraints(ConstraintError), dynamics(DynamicsError), contact(ContactLawError), joints(JointError), loads(LoadError)
}
