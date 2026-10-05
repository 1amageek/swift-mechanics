import ArticulatedDynamicsQualificationSupport

@main
struct ArticulatedDynamicsQualificationRunner {
    static func main() async throws {
        try ArticulatedDynamicsQualificationCases.offsetPendulumGravityAndPower()
        print("Offset COM pendulum gravity/passive force and original energy passed")
        try ArticulatedDynamicsQualificationCases.serialHingeBiasAndPower()
        print("Serial hinge nonzero Coriolis/Newton-Euler and power passed")
        try ArticulatedDynamicsQualificationCases.serialPrismaticCoupling()
        print("Coupled serial spatial prism acceleration and momentum passed")
        try ArticulatedDynamicsQualificationCases.branchedTreeWithFixedCarrier()
        print("Branched tree fixed carrier and original momentum passed")
        try ArticulatedDynamicsQualificationCases.rotatedScrewAndFramedWrench()
        print("Noncommuting rotated screw inertia and body/world wrench passed")
        try ArticulatedDynamicsQualificationCases.inverseMassAndPhysicalNormalization()
        print("Inverse mass retained source and physical normalization passed")
        try ArticulatedDynamicsQualificationCases.typedRefusalsAndWorkPrefixes()
        print("Original typed domain/pivot/budget/work-prefix/callback refusal passed")
        try await ArticulatedDynamicsQualificationNativeCases.taskCancellation()
        print("Actual Native Task cancellation passed")
    }
}
