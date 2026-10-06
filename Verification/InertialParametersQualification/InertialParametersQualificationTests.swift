import SwiftMechanics
#if canImport(InertialParametersQualificationSupport)
import InertialParametersQualificationSupport
#endif
import Testing

@Suite struct InertialParametersQualificationTests {
    @Test func tenCoordinateLiteralOriginLaws() throws { try InertialParametersQualificationCases.tenCoordinateOriginLaws() }
    @Test func uniformGravityAndActualPower() throws { try InertialParametersQualificationCases.uniformGravityAndPower() }
    @Test func rotatedCoupledOriginalDifferences() throws { try InertialParametersQualificationCases.rotatedCoupledDifferences() }
    @Test func originalForwardAccelerationAndRoundtrip() throws { try InertialParametersQualificationCases.forwardAccelerationAndRoundtrip() }
    @Test func sourceIdentityAndMappingRefusals() throws { try InertialParametersQualificationCases.sourceAndMappingRefusals() }
    @Test func physicalNeighborhoodAndOriginalRankRefusals() throws { try InertialParametersQualificationCases.physicalAndRankDomains() }
    @Test func exactCumulativeNumericalAndSupplierWork() throws { try InertialParametersQualificationCases.cumulativeWorkBounds() }
    @Test func callerAndFinalPublicationCancellation() throws { try InertialParametersQualificationCases.callerAndPublicationCancellation() }
    @Test(.timeLimit(.minutes(1))) func actualCancelledTask() async throws {
        let fixture = try InertialParametersQualificationFixture()
        let input = fixture.input, direction = try fixture.direction(combined: true)
        let policy = try InertialParametersQualificationFixture.policy()
        let initialWork = try InertialParametersQualificationFixture.work(seeded: true)
        let initialLoads = try InertialParametersQualificationFixture.loads(seeded: true)
        let initialCalls = try DerivativeSupplierWork(maximumCalls: 100)
        let task = Task { () throws -> Void in
            var work = initialWork, loads = initialLoads, calls = initialCalls
            withUnsafeCurrentTask { $0?.cancel() }
            try InertialParametersQualificationCases.actualTaskCancellation(input, direction: direction,
                fixture: fixture, policy: policy, work: &work, loads: &loads, calls: &calls)
        }
        try await task.value
    }
}
