import TireLawsQualificationSupport

@main
struct TireLawsQualificationRunner {
    static func main() async throws {
        try TireLawsQualificationCases.zeroSlipPureCurvesAndLoad()
        try TireLawsQualificationCases.unequalStiffnessCombinedCone()
        try TireLawsQualificationCases.reverseBrakingAndRollingJump()
        try TireLawsQualificationCases.worldWrenchMovingRoadAndBoost()
        try TireLawsQualificationCases.calibrationAndArithmeticRefusals()
        try TireLawsQualificationCases.geometryRevisionsAndEnvelope()
        try TireLawsQualificationCases.exactWorkPrefixesAndCancellation()
        try await TireLawsQualificationNativeCases.taskCancellation()
        print("TireLaws seven synchronous cases and Native caller cancellation completed")
    }
}
