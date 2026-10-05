import Testing
import ArticulatedDynamicsQualificationSupport

@Suite
struct ArticulatedDynamicsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func offsetPendulumGravityAndPower() throws { try ArticulatedDynamicsQualificationCases.offsetPendulumGravityAndPower() }
    @Test(.timeLimit(.minutes(1))) func serialHingeBiasAndPower() throws { try ArticulatedDynamicsQualificationCases.serialHingeBiasAndPower() }
    @Test(.timeLimit(.minutes(1))) func serialPrismaticCoupling() throws { try ArticulatedDynamicsQualificationCases.serialPrismaticCoupling() }
    @Test(.timeLimit(.minutes(1))) func branchedTreeWithFixedCarrier() throws { try ArticulatedDynamicsQualificationCases.branchedTreeWithFixedCarrier() }
    @Test(.timeLimit(.minutes(1))) func rotatedScrewAndFramedWrench() throws { try ArticulatedDynamicsQualificationCases.rotatedScrewAndFramedWrench() }
    @Test(.timeLimit(.minutes(1))) func inverseMassAndPhysicalNormalization() throws { try ArticulatedDynamicsQualificationCases.inverseMassAndPhysicalNormalization() }
    @Test(.timeLimit(.minutes(1))) func typedRefusalsAndWorkPrefixes() throws { try ArticulatedDynamicsQualificationCases.typedRefusalsAndWorkPrefixes() }
    @Test(.timeLimit(.minutes(1))) func nativeTaskCancellation() async throws { try await ArticulatedDynamicsQualificationNativeCases.taskCancellation() }
}
