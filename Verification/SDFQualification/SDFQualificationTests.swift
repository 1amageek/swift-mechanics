import SwiftMechanics
#if canImport(SDFQualificationSupport)
import SDFQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SDFQualificationTests {
    @Test func originalNestedFramesInertiaAndPhysicalGravity() throws { try SDFQualificationCases.nestedFramesInertiaAndGravity() }
    @Test func actualCompiledQVMotionAndSeparateAttachmentGraph() throws { try SDFQualificationCases.actualJointStateAndAttachment() }
    @Test func originalEulerAndQuaternionConventions() throws { try SDFQualificationCases.poseConventions() }
    @Test func independentOriginalLossSnapshotExportAndStaleness() throws { try SDFQualificationCases.originalLossSnapshotAndStaleSource() }
    @Test func originalSemanticAndAuthorityRefusals() throws { try SDFQualificationCases.semanticRefusals() }
    @Test func actualCapacityAndCancellationReceipts() throws { try SDFQualificationCases.capacitiesAndReceipts() }
    @Test func actualCancelledTaskRefusesEveryPublicPath() async throws {
        let scene = try SDFQualificationCases.cancellationScene()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try SDFQualificationCases.cancelledTask(scene)
        }
        try await task.value
    }
}
