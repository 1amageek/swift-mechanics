public struct ContactPhysicalEvidence: Sendable {
    public let normalLawResidual: Double, normalConeResidual: Double, momentumResidual: Double, wrenchResidual: Double, powerResidual: Double
    public let threshold: Double
    public var isAccepted: Bool { max(normalLawResidual,max(normalConeResidual,max(momentumResidual,max(wrenchResidual,powerResidual)))) <= threshold }
}
