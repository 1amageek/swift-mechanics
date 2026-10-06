import SwiftMechanics
import Testing
#if canImport(RollingRelationsQualificationSupport)
import RollingRelationsQualificationSupport
#endif

@Suite struct RollingRelationsQualificationTests {
    @Test(.timeLimit(.minutes(1))) func straightDisk() throws { try RollingRelationsQualificationCases.straightDisk() }
    @Test(.timeLimit(.minutes(1))) func camberProjection() throws { try RollingRelationsQualificationCases.camberProjection() }
    @Test(.timeLimit(.minutes(1))) func movingPlaneAndPower() throws { try RollingRelationsQualificationCases.movingPlaneAndPower() }
    @Test(.timeLimit(.minutes(1))) func contactFirstDerivative() throws { try RollingRelationsQualificationCases.contactFirstDerivative() }
    @Test(.timeLimit(.minutes(1))) func sourceAndContactRefusals() throws { try RollingRelationsQualificationCases.sourceAndContactRefusals() }
    @Test(.timeLimit(.minutes(1))) func rankAndWorkBounds() throws { try RollingRelationsQualificationCases.rankAndWorkBounds() }
    @Test(.timeLimit(.minutes(1))) func policyAndCancellation() throws { try RollingRelationsQualificationCases.policyAndCancellation() }
    @Test(.timeLimit(.minutes(1))) func actualAwaitedNativeCancellation() async throws {
        let fixture = try RollingRelationsQualificationFixtures()
        let state = try fixture.state(q: [0,0,0,0],v: [0,0,0,0],a: [0,0,0,0]), policy = try fixture.policy()
        let task = Task { () throws -> Void in
            while !Task.isCancelled { await Task.yield() }
            try RollingRelationsQualificationCases.require(Task.isCancelled,"Actual Native Task cancellation")
            try RollingRelationsQualificationCases.cancellation(fixture: fixture,state: state,policy: policy)
        }
        task.cancel()
        try await task.value
    }
}
