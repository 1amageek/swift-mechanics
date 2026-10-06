import SwiftMechanics
#if canImport(ConvexQueriesQualificationSupport)
import ConvexQueriesQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConvexQueriesQualificationTests {
    @Test func originalAnalyticPrimitiveAndHullSupports() throws { try ConvexQueriesQualificationCases.originalSupportMaps() }
    @Test func actualAdaptedGJKMarginAndReversal() throws { try ConvexQueriesQualificationCases.adaptedSeparationAndReversal() }
    @Test func originalPrimitiveHullGJKSeparation() throws { try ConvexQueriesQualificationCases.primitiveAndHullSeparation() }
    @Test func originalBoxEPAPenetration() throws { try ConvexQueriesQualificationCases.originalBoxPenetration() }
    @Test func originalPrimitiveHullEPAPenetration() throws { try ConvexQueriesQualificationCases.primitiveAndHullPenetration() }
    @Test func actualContactBandAndCoincidentBoxes() throws { try ConvexQueriesQualificationCases.touchingAndCoincidentBoxes() }
    @Test func originalRigidCovarianceAndSnapshots() throws { try ConvexQueriesQualificationCases.rigidCovarianceAndSnapshot() }
    @Test func actualOriginalIdentitySourceAndAdmission() throws { try ConvexQueriesQualificationCases.identitySourceAndAdmission() }
    @Test func actualBudgetAndIterationFailures() throws { try ConvexQueriesQualificationCases.boundedWorkAndIterationRefusals() }
    @Test func actualCancelledPublicPaths() async throws {
        var work = try ConvexQueriesQualificationFixtures.work()
        let first = try ConvexQueriesQualificationFixtures.proxy("a",shape:.sphere(radius:1),work:&work)
        let second = try ConvexQueriesQualificationFixtures.proxy("b",shape:.sphere(radius:1),position:Vector3(3,0,0),work:&work)
        let analyticFirst = try ConvexQueriesQualificationFixtures.analytic("aa",shape:.sphere(radius:1))
        let analyticSecond = try ConvexQueriesQualificationFixtures.analytic("ab",shape:.sphere(radius:1),position:Vector3(3,0,0))
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try ConvexQueriesQualificationCases.cancelledPaths(first:first,second:second,
                analyticFirst:analyticFirst,analyticSecond:analyticSecond)
        }
        try await task.value
    }
}
