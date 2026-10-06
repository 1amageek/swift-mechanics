import SwiftMechanics
import Testing
#if canImport(PoseIKQualificationSupport)
import PoseIKQualificationSupport
#endif

@Suite struct PoseIKQualificationTests {
    @Test(.timeLimit(.minutes(1))) func cartesianPoints() throws { try PoseIKQualificationCases.cartesianPoints() }
    @Test(.timeLimit(.minutes(1))) func orientationAndPose() throws { try PoseIKQualificationCases.orientationAndPose() }
    @Test(.timeLimit(.minutes(1))) func redundantReference() throws { try PoseIKQualificationCases.redundantReference() }
    @Test(.timeLimit(.minutes(1))) func timedOriginalLoops() throws { try PoseIKQualificationCases.timedOriginalLoops() }
    @Test(.timeLimit(.minutes(1))) func analyticDerivatives() throws { try PoseIKQualificationCases.analyticDerivatives() }
    @Test(.timeLimit(.minutes(1))) func rankBranchAndBounds() throws { try PoseIKQualificationCases.rankBranchAndBounds() }
    @Test(.timeLimit(.minutes(1))) func sourceWorkAndCancellation() throws { try PoseIKQualificationCases.sourceWorkAndCancellation() }
    @Test(.timeLimit(.minutes(1))) func actualAwaitedNativeTaskCancellation() async throws {
        let model = try PoseIKQualificationFixtures.model()
        let target = try PoseIKQualificationFixtures.target([0.2, -0.1, 0.3])
        let problem = try PoseIKQualificationFixtures.problem(model, tasks: [PoseIKQualificationFixtures.point(model, target: target.translation)])
        let policy = try PoseIKQualificationFixtures.policy()
        let task = Task { () throws -> Void in
            while !Task.isCancelled { await Task.yield() }
            try PoseIKQualificationCases.actualNativeCancellation(problem, policy: policy)
        }
        task.cancel()
        try await task.value
    }
}
