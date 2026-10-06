public protocol NonlinearStateEstimating: Sendable {
    func initialize(plant: PrismaticEstimationModel, timeSeconds: Double, positionMeters: Double, rateMetersPerSecond: Double,
                    normalizedCovariance: [Double], policy: NonlinearEstimatorPolicy,
                    work: inout NumericalWork) throws(NonlinearEstimatorFailure) -> NonlinearEstimatorCheckpoint
    func update(_ checkpoint: NonlinearEstimatorCheckpoint, request: NonlinearEstimatorRequest, policy: NonlinearEstimatorPolicy,
                work: inout NumericalWork) throws(NonlinearEstimatorFailure) -> NonlinearEstimatorResult
}
