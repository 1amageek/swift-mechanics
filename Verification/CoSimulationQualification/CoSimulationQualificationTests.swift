import Testing
#if canImport(CoSimulationQualificationSupport)
import CoSimulationQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct CoSimulationQualificationTests {
    @Test func heldPhysical() throws { try run(.heldPhysical) }
    @Test func pureDamper() throws { try run(.pureDamper) }
    @Test func evidenceRollback() throws { try run(.evidenceRollback) }
    @Test func secondRefusalRollback() throws { try run(.secondRefusalRollback) }
    @Test func cumulativeCapacity() throws { try run(.cumulativeCapacity) }
    @Test func admissionRefusals() throws { try run(.admissionRefusals) }
    @Test func staleAndShutdown() throws { try run(.staleAndShutdown) }
    @Test func reentry() throws { try run(.reentry) }
    @Test func cancellationPoison() throws { try run(.cancellationPoison) }
    private func run(_ selected:CoSimulationQualificationCase) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw CoSimulationQualificationError.unsupportedPlatform
        }
        let qualification:any CoSimulationQualifying=CoSimulationQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw CoSimulationQualificationError.unsupportedPlatform
        }
        let entry=try CoSimulationQualificationCases().taskCancellationEntry()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
