import SwiftMechanics
import Testing
#if canImport(HydroelasticQualificationSupport)
import HydroelasticQualificationSupport
#endif

@Suite(.timeLimit(.minutes(1)))
struct HydroelasticQualificationTests {
    @Test func rigidTriangle() throws { try run(.rigidTriangle) }
    @Test func rigidQuadrilateral() throws { try run(.rigidQuadrilateral) }
    @Test func twoFieldsReciprocal() throws { try run(.twoFieldsReciprocal) }
    @Test func currentGeometryAndCovariance() throws { try run(.currentGeometryAndCovariance) }
    @Test func domainsAndStaleness() throws { try run(.domainsAndStaleness) }
    @Test func budgetsAndCancellation() throws { try run(.budgetsAndCancellation) }

    private func run(_ selected: HydroelasticQualificationCase) throws {
        let qualification: any HydroelasticQualifying = HydroelasticQualificationCases()
        try qualification.run(selected)
    }

    @Test func actualTaskCancellationIsAwaited() async throws {
        let entry = try HydroelasticQualificationCases().taskCancellationEntry()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try entry()
        }
        try await task.value
    }
}
