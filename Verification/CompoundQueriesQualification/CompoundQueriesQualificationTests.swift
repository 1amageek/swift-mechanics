import SwiftMechanics
#if canImport(CompoundQueriesQualificationSupport)
import CompoundQueriesQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct CompoundQueriesQualificationTests {
    @Test func independentTransformedOriginalWitnesses() throws { try CompoundQueriesQualificationCases.transformedOriginalWitnesses() }
    @Test func completeChildPairAndRayOrdering() throws { try CompoundQueriesQualificationCases.deterministicPairsAndRays() }
    @Test func originalQualifiedAnalyticFeatures() throws { try CompoundQueriesQualificationCases.originalAnalyticFeatures() }
    @Test func actualFiltersFidelityAndHonestRefusals() throws { try CompoundQueriesQualificationCases.filtersFidelityAndExplicitRefusal() }
    @Test func boundedOriginalIdentityAndMetadataAdmission() throws { try CompoundQueriesQualificationCases.admissionAndMetadataBoundaries() }
    @Test func exactWorkAndCapacityConsumption() throws { try CompoundQueriesQualificationCases.exactWorkAndResourceBoundaries() }
    @Test func laterFailureCannotPublishPartialResults() throws { try CompoundQueriesQualificationCases.transactionalLateRefusals() }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let pair = try CompoundQueriesQualificationFixture.pair()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try CompoundQueriesQualificationCases.cancelledTask(first: pair.0, second: pair.1)
        }
        try await task.value
    }
}
