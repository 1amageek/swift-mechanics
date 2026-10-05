import Testing
#if canImport(FieldOutputsQualificationSupport)
import FieldOutputsQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct FieldOutputsQualificationTests {
    @Test func affineShearAndSampling() throws { try run(.affineShearAndSampling) }
    @Test func volumetricAndAssembly() throws { try run(.volumetricAndAssembly) }
    @Test func rotationWithinDomain() throws { try run(.rotationWithinDomain) }
    @Test func averagingAndMaterials() throws { try run(.averagingAndMaterials) }
    @Test func sourceAndLocationRefusals() throws { try run(.sourceAndLocationRefusals) }
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: FieldOutputsQualificationCase) throws {
        let qualification: any FieldOutputsQualifying=FieldOutputsQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry=try FieldOutputsQualificationCases().taskCancellationEntry()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
