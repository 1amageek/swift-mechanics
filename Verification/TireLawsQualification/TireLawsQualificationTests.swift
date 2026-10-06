import Testing
import TireLawsQualificationSupport

@Suite struct TireLawsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func zeroSlipPureCurvesAndLoad() throws {try TireLawsQualificationCases.zeroSlipPureCurvesAndLoad()}
    @Test(.timeLimit(.minutes(1))) func unequalStiffnessCombinedCone() throws {try TireLawsQualificationCases.unequalStiffnessCombinedCone()}
    @Test(.timeLimit(.minutes(1))) func reverseBrakingAndRollingJump() throws {try TireLawsQualificationCases.reverseBrakingAndRollingJump()}
    @Test(.timeLimit(.minutes(1))) func worldWrenchMovingRoadAndBoost() throws {try TireLawsQualificationCases.worldWrenchMovingRoadAndBoost()}
    @Test(.timeLimit(.minutes(1))) func calibrationAndArithmeticRefusals() throws {try TireLawsQualificationCases.calibrationAndArithmeticRefusals()}
    @Test(.timeLimit(.minutes(1))) func geometryRevisionsAndEnvelope() throws {try TireLawsQualificationCases.geometryRevisionsAndEnvelope()}
    @Test(.timeLimit(.minutes(1))) func exactWorkPrefixesAndCancellation() throws {try TireLawsQualificationCases.exactWorkPrefixesAndCancellation()}
    @Test(.timeLimit(.minutes(1))) func taskCancellation() async throws {try await TireLawsQualificationNativeCases.taskCancellation()}
}
