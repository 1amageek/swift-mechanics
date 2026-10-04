internal struct IdentificationContext {
    var phase: IdentificationPhase = .admission
    var reserved: Int = 0
    var metadataBytes: Int = 0
    var modelAttempts: Int = 0
    var unavailable: Bool = false
    var residual: Double?
    var objective: Double?
}
