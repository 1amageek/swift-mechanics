public protocol LinearEstimating: Sendable {
    func admit(source: ModelStamp, filterIdentity: String, filterRevision: UInt64, chartIdentity: String,
               clock: LinearEstimatorClock, stateCoordinates: [LinearEstimatorCoordinate],
               inputCoordinates: [LinearEstimatorCoordinate], observationCoordinates: [LinearEstimatorCoordinate],
               transition: DenseMatrix<Double>, input: DenseMatrix<Double>, observation: DenseMatrix<Double>,
               processCovariance: DenseMatrix<Double>, observationCovariance: DenseMatrix<Double>,
               policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorModel
    func initialize(model: LinearEstimatorModel, mean: [Double], covariance: DenseMatrix<Double>,
                    policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState
    func predict(_ prefix: LinearEstimatorState, input: LinearEstimatorInput, policy: LinearEstimatorPolicy,
                 work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState
    func update(_ prefix: LinearEstimatorState, observation: LinearEstimatorObservation?, missing: LinearEstimatorMissingPolicy,
                policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorUpdate
}
