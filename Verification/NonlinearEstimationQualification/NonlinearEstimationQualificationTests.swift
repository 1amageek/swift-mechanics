import SwiftMechanics
import Testing
#if canImport(NonlinearEstimationQualificationSupport)
import NonlinearEstimationQualificationSupport
#endif

@Suite struct NonlinearEstimationQualificationTests {
    @Test(.timeLimit(.minutes(1))) func originalMechanicsAndPhysicalJacobian() throws { try NonlinearEstimationQualificationCases.originalMechanicsAndPhysicalJacobian() }
    @Test(.timeLimit(.minutes(1))) func originalRK4AndDiscreteTransition() throws { try NonlinearEstimationQualificationCases.originalRK4AndDiscreteTransition() }
    @Test(.timeLimit(.minutes(1))) func originalInnovationAndJoseph() throws { try NonlinearEstimationQualificationCases.originalInnovationAndJoseph() }
    @Test(.timeLimit(.minutes(1))) func originalScaledCovariance() throws { try NonlinearEstimationQualificationCases.originalScaledCovariance() }
    @Test(.timeLimit(.minutes(1))) func originalTimeSourceAndDomain() throws { try NonlinearEstimationQualificationCases.originalTimeSourceAndDomain() }
    @Test(.timeLimit(.minutes(1))) func originalPSDAndCovariance() throws { try NonlinearEstimationQualificationCases.originalPSDAndCovariance() }
    @Test(.timeLimit(.minutes(1))) func originalWorkCapacityAndCancellation() throws { try NonlinearEstimationQualificationCases.originalWorkCapacityAndCancellation() }
    @Test(.timeLimit(.minutes(1))) func actualAwaitedNativeTaskCancellation() async throws {
        let plant = try NonlinearEstimationQualificationFixtures.plant()
        let checkpoint = try NonlinearEstimationQualificationFixtures.initial(plant)
        let task = Task { () throws -> Void in
            while !Task.isCancelled { await Task.yield() }
            try NonlinearEstimationQualificationCases.actualNativeCancellation(checkpoint: checkpoint)
        }
        task.cancel()
        try await task.value
    }
}
