import SwiftMechanics
import Testing
#if canImport(FrictionalImpulseQualificationSupport)
import FrictionalImpulseQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct FrictionalImpulseQualificationTests {
    @available(macOS 15.0, *)
    @Test func originalStickingImpulseAndEnergy() throws { try FrictionalImpulseQualificationCases().run(.sticking) }
    @available(macOS 15.0, *)
    @Test func originalIsotropicAndAnisotropicSliding() throws { try FrictionalImpulseQualificationCases().run(.sliding) }
    @available(macOS 15.0, *)
    @Test func originalRestitutionThresholdBasisAndSI() throws { try FrictionalImpulseQualificationCases().run(.lawsAndScaling) }
    @available(macOS 15.0, *)
    @Test func originalPrescribedWallWork() throws { try FrictionalImpulseQualificationCases().run(.prescribedWall) }
    @available(macOS 15.0, *)
    @Test func originalTypedRefusals() throws { try FrictionalImpulseQualificationCases().run(.refusals) }
    @available(macOS 15.0, *)
    @Test func originalResourcesAndEarlyLateCancellation() throws { try FrictionalImpulseQualificationCases().run(.resourcesAndCancellation) }
    @available(macOS 15.0, *)
    @Test func actualTaskCancellationIsAwaited() async throws {
        let input = try FrictionalImpulseQualificationFixtures.input()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try FrictionalImpulseQualificationCases().actualTaskCancellation(input)
        }
        try await task.value
    }
}
