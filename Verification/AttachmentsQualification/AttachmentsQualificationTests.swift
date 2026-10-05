import Testing
#if canImport(AttachmentsQualificationSupport)
import AttachmentsQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct AttachmentsQualificationTests {
    @Test func floatingTangentVelocity() throws { try run(.floatingTangentVelocity) }
    @Test func sphericalTangentVelocity() throws { try run(.sphericalTangentVelocity) }
    @Test func prescribedDerivative() throws { try run(.prescribedDerivative) }
    @Test func originalVirtualWork() throws { try run(.originalVirtualWork) }
    @Test func identityAndPhysicalRefusals() throws { try run(.identityAndPhysicalRefusals) }
    @available(macOS 15.0, *)
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: AttachmentsQualificationCase) throws {
        let qualification: any AttachmentsQualifying=AttachmentsQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry=try AttachmentsQualificationCases().taskCancellationEntry()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
