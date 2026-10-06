internal struct LocalKKTContext {
    var phase: LocalOptimizationPhase = .admission
    var reserved=0
    var unavailable=false
    var residual: Double?
}
