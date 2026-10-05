import AffineRigidGravityQualificationSupport

@main
struct AffineRigidGravityQualification {
    static func main() throws {
        try AffineRigidGravityQualificationCases.continuumPointIntegral()
        print("AffineRigidGravity independent continuum point integral passed")
        try AffineRigidGravityQualificationCases.properRotationCovariance()
        print("AffineRigidGravity original proper-rotation covariance passed")
        try AffineRigidGravityQualificationCases.potentialFiniteDifferences()
        print("AffineRigidGravity translation, rotation and explicit time potential derivatives passed")
        try AffineRigidGravityQualificationCases.independentInstantaneousPower()
        print("AffineRigidGravity original point velocity power and total rate passed")
        try AffineRigidGravityQualificationCases.originalKernelPrescribedPower()
        print("AffineRigidGravity original kernel JT and prescribed work passed")
        try AffineRigidGravityQualificationCases.sourceAndDomainRefusals()
        print("AffineRigidGravity source, frame and unsupported typed refusals passed")
        try AffineRigidGravityQualificationCases.exactWorkCapacityCancellation()
        print("AffineRigidGravity exact work, capacity and cancellation passed")
        try AffineRigidGravityQualificationCases.originalSupplierAndMomentRefusals()
        print("AffineRigidGravity original supplier overflow and physical moment refusals passed")
    }
}
