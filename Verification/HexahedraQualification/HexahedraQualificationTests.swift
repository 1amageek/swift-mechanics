import Testing
#if canImport(HexahedraQualificationSupport)
import HexahedraQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct HexahedraQualificationTests {
    @Test func affinePatchAndTangent() throws { try run(.affinePatchAndTangent) }
    @Test func nonAffineEnergyGradient() throws { try run(.nonAffineEnergyGradient) }
    @Test func finiteObjectivityAndRigidModes() throws { try run(.finiteObjectivityAndRigidModes) }
    @Test func massAndMaterialAssignments() throws { try run(.massAndMaterialAssignments) }
    @Test func geometryAndBindingRefusals() throws { try run(.geometryAndBindingRefusals) }
    @available(macOS 15.0, *)
    @Test func resourcesAndCancellation() throws { try run(.resourcesAndCancellation) }
    private func run(_ selected: HexahedraQualificationCase) throws {
        let qualification: any HexahedraQualifying=HexahedraQualificationCases()
        try qualification.run(selected)
    }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry=try HexahedraQualificationCases().taskCancellationEntry()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
