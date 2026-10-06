public enum AffineRigidGravityFailure: Error, Equatable, Sendable {
    case invalidInput
    case staleSource
    case frameMismatch
    case unsupportedSpatialDomain
    case unsupportedGradientTimeDerivative
    case unsupportedTemporalWrenchBridge
    case nonphysicalSecondMoment
    case invalidSupplierOutput
    case duplicateGravityOwnership
    case powerResidual
    case nonFiniteResult
    case core(CoreError)
    case joints(JointError)
    case loads(LoadError)
    case dynamics(DynamicsError)
}
