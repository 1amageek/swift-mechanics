import SwiftMechanics
// Canonical tests co-locate the same fixture sources; isolated profiles import their support target.
#if canImport(MJCFQualificationSupport)
import MJCFQualificationSupport
#endif
import Testing

@Suite struct MJCFQualificationTests {
    @Test(.timeLimit(.minutes(1))) func originalSlideDefaultsInertiaAndMotion() throws { try MJCFQualificationCases.originalSlideDefaultsAndInertia() }
    @Test(.timeLimit(.minutes(1))) func originalDegreeReferenceAndOffsetHinge() throws { try MJCFQualificationCases.originalOffsetHingeAndDegreeReference() }
    @Test(.timeLimit(.minutes(1))) func originalMotorPowerSensorsAndPhysicalEquality() throws { try MJCFQualificationCases.originalAffinePowerSensorsAndEquality() }
    @Test(.timeLimit(.minutes(1))) func originalLossesAndActualExports() throws { try MJCFQualificationCases.sourceLossProvenanceAndExport() }
    @Test(.timeLimit(.minutes(1))) func opaqueCADAuthorityAndOriginalAssetLosses() throws { try MJCFQualificationCases.opaqueCADAuthorityAndRetainedAssets() }
    @Test(.timeLimit(.minutes(1))) func originalTypedRejections() throws { try MJCFQualificationCases.originalTypedRefusals() }
    @Test(.timeLimit(.minutes(1))) func originalResourcesCancellationAndReceipts() throws { try MJCFQualificationCases.budgetsCancellationAndReceipts() }
    @Test(.timeLimit(.minutes(1))) func actualTaskCancellationRefusesPublication() async throws {
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try MJCFQualificationCases.expect("<mujoco><worldbody/></mujoco>") { if case .cancelled = $0 { true } else { false } }
        }
        try await task.value
    }
}
