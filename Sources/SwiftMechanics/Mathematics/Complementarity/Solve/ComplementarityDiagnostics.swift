
public struct ComplementarityDiagnostics: Sendable {
    public let precision: NumericalPrecision
    public let backend: NumericalBackend
    public let projectedIterations: Int
    public let work: NumericalWork
    public let originalResidual: ConeResidualEvidence
    public let usedWarmStart: Bool
    public let inverseRowBound: Double
    public var termination: NumericalTermination { .accepted }
}
