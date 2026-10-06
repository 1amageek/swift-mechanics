public struct LinearEstimatorModel: Sendable {
    public let source: ModelStamp
    public let filterIdentity: String
    public let filterRevision: UInt64
    public let chartIdentity: String
    public let clock: LinearEstimatorClock
    public let stateCoordinates: [LinearEstimatorCoordinate]
    public let inputCoordinates: [LinearEstimatorCoordinate]
    public let observationCoordinates: [LinearEstimatorCoordinate]
    public let transition: DenseMatrix<Double>
    public let input: DenseMatrix<Double>
    public let observation: DenseMatrix<Double>
    public let processCovariance: DenseMatrix<Double>
    public let observationCovariance: DenseMatrix<Double>
    internal init(source: ModelStamp, filterIdentity: String, filterRevision: UInt64, chartIdentity: String,
                  clock: LinearEstimatorClock, stateCoordinates: [LinearEstimatorCoordinate],
                  inputCoordinates: [LinearEstimatorCoordinate], observationCoordinates: [LinearEstimatorCoordinate],
                  transition: DenseMatrix<Double>, input: DenseMatrix<Double>, observation: DenseMatrix<Double>,
                  processCovariance: DenseMatrix<Double>, observationCovariance: DenseMatrix<Double>) {
        self.source = source; self.filterIdentity = filterIdentity; self.filterRevision = filterRevision
        self.chartIdentity = chartIdentity; self.clock = clock; self.stateCoordinates = stateCoordinates
        self.inputCoordinates = inputCoordinates; self.observationCoordinates = observationCoordinates
        self.transition = transition; self.input = input; self.observation = observation
        self.processCovariance = processCovariance; self.observationCovariance = observationCovariance
    }
}
