import Testing
import WheeledAssembliesQualificationSupport

@Suite struct WheeledAssembliesQualificationTests {
    @Test(.timeLimit(.minutes(1))) func gravityAndOriginalMomentum() throws {try WheeledAssembliesQualificationCases.gravityAndOriginalMomentum()}
    @Test(.timeLimit(.minutes(1))) func suppliedForceAndHeldEvolution() throws {try WheeledAssembliesQualificationCases.suppliedForceAndHeldEvolution()}
    @Test(.timeLimit(.minutes(1))) func springReactionAndSuppliedNormals() throws {try WheeledAssembliesQualificationCases.springReactionAndSuppliedNormals()}
    @Test(.timeLimit(.minutes(1))) func dampingAndInternalMomentum() throws {try WheeledAssembliesQualificationCases.dampingAndInternalMomentum()}
    @Test(.timeLimit(.minutes(1))) func shaftAndChassisReaction() throws {try WheeledAssembliesQualificationCases.shaftAndChassisReaction()}
    @Test(.timeLimit(.minutes(1))) func steeringAndOppositeSpinBrakes() throws {try WheeledAssembliesQualificationCases.steeringAndOppositeSpinBrakes()}
    @Test(.timeLimit(.minutes(1))) func refusalsAndFailedTrialOwnership() throws {try WheeledAssembliesQualificationCases.refusalsAndFailedTrialOwnership()}
    @Test(.timeLimit(.minutes(1))) func taskCancellation() async throws {try await WheeledAssembliesQualificationNativeCases.taskCancellation()}
}
