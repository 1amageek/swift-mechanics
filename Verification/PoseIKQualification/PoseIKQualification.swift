#if canImport(PoseIKQualificationSupport)
import PoseIKQualificationSupport
#endif

@main struct PoseIKQualification {
    static func main() throws {
        try PoseIKQualificationCases.cartesianPoints()
        print("POSE_IK Cartesian points GREEN")
        try PoseIKQualificationCases.orientationAndPose()
        print("POSE_IK orientation and pose GREEN")
        try PoseIKQualificationCases.redundantReference()
        print("POSE_IK redundant reference GREEN")
        try PoseIKQualificationCases.timedOriginalLoops()
        print("POSE_IK timed original loops GREEN")
        try PoseIKQualificationCases.analyticDerivatives()
        print("POSE_IK analytic derivatives GREEN")
        try PoseIKQualificationCases.rankBranchAndBounds()
        print("POSE_IK rank branch and bounds GREEN")
        try PoseIKQualificationCases.sourceWorkAndCancellation()
        print("POSE_IK source work and cancellation GREEN")
    }
}
