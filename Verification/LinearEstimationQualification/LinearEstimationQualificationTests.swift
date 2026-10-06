import Testing
#if canImport(LinearEstimationQualificationSupport)
import LinearEstimationQualificationSupport
#endif

@Suite struct LinearEstimationQualificationTests {
    @Test(.timeLimit(.minutes(1))) func scalarPredictionInnovationAndJoseph() throws { try LinearEstimationQualificationCases.scalarPredictionInnovationAndJoseph() }
    @Test(.timeLimit(.minutes(1))) func coupledStatesAndMeasurements() throws { try LinearEstimationQualificationCases.coupledStatesAndMeasurements() }
    @Test(.timeLimit(.minutes(1))) func observabilityAndCovarianceAdmission() throws { try LinearEstimationQualificationCases.observabilityAndCovarianceAdmission() }
    @Test(.timeLimit(.minutes(1))) func clockMissingAndSourceRefusals() throws { try LinearEstimationQualificationCases.clockMissingAndSourceRefusals() }
    @Test(.timeLimit(.minutes(1))) func continuationBitsAndRefusals() throws { try LinearEstimationQualificationCases.continuationBitsAndRefusals() }
    @Test(.timeLimit(.minutes(1))) func budgetsAndCallbackCancellation() throws { try LinearEstimationQualificationCases.budgetsAndCallbackCancellation() }
    @Test(.timeLimit(.minutes(1))) func failedSupplierReservationAndPrefix() throws { try LinearEstimationQualificationCases.failedSupplierReservationAndPrefix() }
    @Test(.timeLimit(.minutes(1))) func actualNativeTaskCancellation() async throws { try await LinearEstimationQualificationNativeCases.cancelledTaskRetainsOriginalPrefix() }
}
