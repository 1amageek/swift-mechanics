import Testing
#if canImport(RefinementQualificationSupport)
import RefinementQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct RefinementQualificationTests {
    @Test func topologyAndBoundary() throws { try run(.topologyAndBoundary) }
    @Test func diagonalGeometry() throws { try run(.diagonalGeometry) }
    @Test func sharedAndDisconnected() throws { try run(.sharedAndDisconnected) }
    @Test func stateAndConcentratedLoads() throws { try run(.stateAndConcentratedLoads) }
    @Test func originalRefusals() throws { try run(.originalRefusals) }
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: RefinementQualificationCase) throws {
        let qualification: any RefinementQualifying=RefinementQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry=try RefinementQualificationCases().taskCancellationEntry()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
