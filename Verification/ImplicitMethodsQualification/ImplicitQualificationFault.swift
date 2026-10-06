public enum ImplicitQualificationFault: Equatable, Sendable {
    case none
    case prepareFailure
    case preparePhysicalMutation
    case missingDerivative
    case wrongTangent
    case writeMismatch
    case resetLedger
    case unavailableFailure
    case originalBalanceMismatch
}
