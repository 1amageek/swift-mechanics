import SwiftMechanics
#if canImport(ExternalCommandsQualificationSupport)
import ExternalCommandsQualificationSupport
#endif
import Testing

@Suite struct ExternalCommandsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func delayLinearExactSI() throws { try ExternalCommandQualificationCases.delayedLinearAndExactSI() }
    @Test(.timeLimit(.minutes(1))) func holdRestorePruneReplay() throws { try ExternalCommandQualificationCases.holdRestorePruneAndReplay() }
    @Test(.timeLimit(.minutes(1))) func actualServoForcePowerWork() throws { try ExternalCommandQualificationCases.actualServoMechanicalWork() }
    @Test(.timeLimit(.minutes(1))) func arrivalAgeGapClock() throws { try ExternalCommandQualificationCases.arrivalAgeGapAndClockRefusals() }
    @Test(.timeLimit(.minutes(1))) func sourceUnitOrderFailureWork() throws { try ExternalCommandQualificationCases.originalIdentityUnitsOrderAndFailureWork() }
    @Test(.timeLimit(.minutes(1))) func capacityOverflow() throws { try ExternalCommandQualificationCases.capacitiesAndOverflow() }
    @Test(.timeLimit(.minutes(1))) func actualCancelledPublicAppend() async throws {
        let checkpoint = try ExternalCommandQualificationFixtures.checkpoint()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try ExternalCommandQualificationCases.actualTaskCancellation(checkpoint: checkpoint)
        }
        try await task.value
    }
}
