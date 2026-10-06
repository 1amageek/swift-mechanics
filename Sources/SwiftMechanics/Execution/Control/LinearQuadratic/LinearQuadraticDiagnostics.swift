public struct LinearQuadraticDiagnostics: Sendable {
    public let riccatiIterations: Int
    public let originalRiccatiResidual: Double
    public let originalGainResidual: Double
    public let maximumRiccatiAsymmetry: Double
    public let witnessLyapunovResidual: Double
    public let closedLoopLyapunovResidual: Double
    /// Positive-definite W and original W-F^T*W*F establish strict Schur stability.
    public let closedLoopLyapunovMatrix: [Double]
    public let work: NumericalWork
    public let precision = NumericalPrecision.float64
    public let backend = NumericalBackend.referenceCPU
}
