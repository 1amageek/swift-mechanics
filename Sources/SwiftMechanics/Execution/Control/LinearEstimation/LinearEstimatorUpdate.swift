public struct LinearEstimatorUpdate: Sendable {
    public let state: LinearEstimatorState
    public let innovation: [Double]?
    public let gain: DenseMatrix<Double>?
    public let innovationCovariance: DenseMatrix<Double>?
    public let supplierSolveDiagnostics: [LinearDiagnostics<Double>]
    public let missingObservation: Bool
}
