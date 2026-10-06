import Testing
#if canImport(ShellsQualificationSupport)
import ShellsQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct ShellsQualificationTests {
    @Test func membranePatch() throws { try run(.membranePatch) }
    @Test func bendingAndShear() throws { try run(.bendingAndShear) }
    @Test func massAndDamping() throws { try run(.massAndDamping) }
    @Test func rigidFrameAndPower() throws { try run(.rigidFrameAndPower) }
    @Test func originalRefusals() throws { try run(.originalRefusals) }
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: ShellsQualificationCase) throws {
        guard #available(macOS 15.0, *) else { throw ShellsQualificationError.unsupportedNativePlatform }
        let suite: any ShellsQualifying = ShellsQualificationCases(); try suite.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        guard #available(macOS 15.0, *) else { throw ShellsQualificationError.unsupportedNativePlatform }
        let entry = try ShellsQualificationCases().taskCancellationEntry()
        let task = Task { () throws -> Void in withUnsafeCurrentTask { $0?.cancel() }; try entry() }
        try await task.value
    }
}
