public enum AttachmentsQualificationCase: CaseIterable, Sendable {
    case floatingTangentVelocity, sphericalTangentVelocity, prescribedDerivative
    case originalVirtualWork, identityAndPhysicalRefusals, resourcesAndCancellation
    public var label: String {
        switch self {
        case .floatingTangentVelocity: "floating tangent velocity"
        case .sphericalTangentVelocity: "spherical tangent velocity"
        case .prescribedDerivative: "prescribed derivative"
        case .originalVirtualWork: "original virtual work"
        case .identityAndPhysicalRefusals: "identity and physical refusals"
        case .resourcesAndCancellation: "resources and cancellation"
        }
    }
}
