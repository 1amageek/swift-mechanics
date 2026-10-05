import Testing
#if canImport(ParticleFlowsQualificationSupport)
import ParticleFlowsQualificationSupport
#endif

@Suite struct ParticleFlowsQualificationTests {
    @Test func originalKernelNormalization() throws { try ParticleFlowsQualificationCases.kernelNormalization() }
    @Test func originalDensityAndEOS() throws { try ParticleFlowsQualificationCases.densityAndEOS() }
    @Test func originalMidpointMomentumEnergy() throws { try ParticleFlowsQualificationCases.midpointMomentumEnergy() }
    @Test func originalViscosityAndHeat() throws { try ParticleFlowsQualificationCases.viscosityAndHeat() }
    @Test func originalPrescribedGhostWork() throws { try ParticleFlowsQualificationCases.prescribedGhostWork() }
    @Test func originalAdmissionAndTime() throws { try ParticleFlowsQualificationCases.admissionAndTime() }
    @Test func originalExactWorkBounds() throws { try ParticleFlowsQualificationCases.exactWorkBounds() }
    @Test func actualNativeTaskCancellation() async throws { try await ParticleFlowsQualificationCases.nativeCancellation() }
}
