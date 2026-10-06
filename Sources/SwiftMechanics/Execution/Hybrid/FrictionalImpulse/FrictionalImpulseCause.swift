public enum FrictionalImpulseCause: Error, Sendable {
    case invalidInput, invalidShape, capacityExceeded, staleSource, invalidWitness, frameMismatch, stalePose
    case unsupportedDomain, nonapproaching, coupledNormalTangent, singularTangent, ambiguousBoundary
    case nonconvergence, cancelled, nonFiniteResult, invalidSupplierLedger, invalidSupplierOutput, unexpectedSupplierFailure
    case momentumRejected(value: Double, threshold: Double)
    case velocityRejected(value: Double, threshold: Double)
    case coulombRejected(value: Double, threshold: Double)
    case workRejected(value: Double, threshold: Double)
    case energyRejected(value: Double, threshold: Double)
    case core(CoreError), joints(JointError), numerical(NumericalError), dynamics(DynamicsError)
    case contact(ContactLawError), loads(LoadError)
}
