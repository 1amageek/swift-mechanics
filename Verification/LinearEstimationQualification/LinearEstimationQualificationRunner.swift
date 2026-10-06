import LinearEstimationQualificationSupport

@main
struct LinearEstimationQualificationRunner {
    static func main() async throws {
        try LinearEstimationQualificationCases.scalarPredictionInnovationAndJoseph()
        print("Original scalar prediction, innovation, gain and Joseph covariance passed")
        try LinearEstimationQualificationCases.coupledStatesAndMeasurements()
        print("Independent coupled state and measurement covariance oracles passed")
        try LinearEstimationQualificationCases.observabilityAndCovarianceAdmission()
        print("Original observability, PSD, SPD, symmetry and admission refusals passed")
        try LinearEstimationQualificationCases.clockMissingAndSourceRefusals()
        print("Original tick, missing, stale, ordering, source and layout contracts passed")
        try LinearEstimationQualificationCases.continuationBitsAndRefusals()
        print("Original contributor payload bits, replay and corruption refusals passed")
        try LinearEstimationQualificationCases.budgetsAndCallbackCancellation()
        print("Original cumulative work, storage, iteration and callback cancellation prefixes passed")
        try LinearEstimationQualificationCases.failedSupplierReservationAndPrefix()
        print("Original failed Cholesky cause and unavailable executed-work reservation passed")
        try await LinearEstimationQualificationNativeCases.cancelledTaskRetainsOriginalPrefix()
        print("Separate actual Native Task cancellation prefix passed")
    }
}
