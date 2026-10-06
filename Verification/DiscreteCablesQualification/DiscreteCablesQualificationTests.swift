import Testing
#if canImport(DiscreteCablesQualificationSupport)
import DiscreteCablesQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct DiscreteCablesQualificationTests {
    @Test func stretchAndUnilateral() throws { try run(.stretchAndUnilateral) }
    @Test func independentDerivatives() throws { try run(.independentDerivatives) }
    @Test func bendAndPrestress() throws { try run(.bendAndPrestress) }
    @Test func rigidCovariance() throws { try run(.rigidCovariance) }
    @Test func massAndDrag() throws { try run(.massAndDrag) }
    @Test func gravityAndSupport() throws { try run(.gravityAndSupport) }
    @Test func dragAndTransactionalRollback() throws { try run(.dragAndTransactionalRollback) }
    @Test func resourceAndIdentityRefusals() throws { try run(.resourceAndIdentityRefusals) }
    @Test func cancellation() throws { try run(.cancellation) }
    private func run(_ selected: DiscreteCablesQualificationCase) throws {
        let qualification: any DiscreteCablesQualifying = DiscreteCablesQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry = try DiscreteCablesQualificationCases().taskCancellationEntry()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
