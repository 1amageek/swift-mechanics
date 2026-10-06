import WheeledAssembliesQualificationSupport

@main
struct WheeledAssembliesQualificationRunner {
    static func main() async throws {
        try WheeledAssembliesQualificationCases.gravityAndOriginalMomentum()
        try WheeledAssembliesQualificationCases.suppliedForceAndHeldEvolution()
        try WheeledAssembliesQualificationCases.springReactionAndSuppliedNormals()
        try WheeledAssembliesQualificationCases.dampingAndInternalMomentum()
        try WheeledAssembliesQualificationCases.shaftAndChassisReaction()
        try WheeledAssembliesQualificationCases.steeringAndOppositeSpinBrakes()
        try WheeledAssembliesQualificationCases.refusalsAndFailedTrialOwnership()
        try await WheeledAssembliesQualificationNativeCases.taskCancellation()
        print("WheeledAssemblies seven synchronous cases and Native cancellation completed")
    }
}
