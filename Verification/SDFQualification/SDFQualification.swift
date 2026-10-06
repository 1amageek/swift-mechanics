import SDFQualificationSupport

@main
struct SDFQualification {
    static func main() throws {
        try SDFQualificationCases.nestedFramesInertiaAndGravity()
        print("SDF original nested frames, transformed inertia and physical gravity witness passed")
        try SDFQualificationCases.actualJointStateAndAttachment()
        print("SDF actual compiled q/v/acceleration and separate attachment witness passed")
        try SDFQualificationCases.poseConventions()
        print("SDF original Euler and quaternion orientation witness passed")
        try SDFQualificationCases.originalLossSnapshotAndStaleSource()
        print("SDF independent original snapshot export, explicit loss and stale-source witness passed")
        try SDFQualificationCases.semanticRefusals()
        print("SDF original semantic, inertia, number and asset authority refusal witness passed")
        try SDFQualificationCases.capacitiesAndReceipts()
        print("SDF actual bounded work and caller cancellation receipt witness passed")
    }
}
