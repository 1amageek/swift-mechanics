internal struct EnumerationContext: Sendable {
    var phase: OptimizationPhase = .admission
    var processed=0
    var isPhaseOne=false
    var lastFeasibility: Double?
    var failedSupplierWorkUnavailable=false
}
