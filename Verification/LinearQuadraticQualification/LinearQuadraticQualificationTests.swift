import SwiftMechanics
#if canImport(LinearQuadraticQualificationSupport)
import LinearQuadraticQualificationSupport
#endif
import Testing

@Suite struct LinearQuadraticQualificationTests {
    @Test func representedCostPrincipalMinorBoundaries() throws { try LinearQuadraticCostBoundaryQualification.run() }
    @Test func independentAnalyticScalarRoots() throws { try LinearQuadraticQualificationCases.analyticScalarRoots() }
    @Test func diagonalOriginalMatrixAndCostEquations() throws { try LinearQuadraticQualificationCases.diagonalMatrixEquations() }
    @Test func actualMechanicalRealizationAndDynamics() throws { try LinearQuadraticQualificationCases.mechanicalRealizationAndDynamics() }
    @Test func physicalUnitsAndDisclosedSaturation() throws { try LinearQuadraticQualificationCases.unitsAndSaturation() }
    @Test func sourceAndPhysicalPortRefusals() throws { try LinearQuadraticQualificationCases.sourceAndPortRefusals() }
    @Test func costWitnessAndOriginalStabilityRefusals() throws { try LinearQuadraticQualificationCases.costAndStabilityRefusals() }
    @Test func cumulativeWorkAndActualSupplierFailures() throws { try LinearQuadraticQualificationCases.cumulativeWorkAndSupplierFailures() }
    @Test func callerAndFinalPublicationCancellation() throws { try LinearQuadraticQualificationCases.callerAndPublicationCancellation() }
    @Test(.timeLimit(.minutes(1))) func actualCancelledTask() async throws {
        let system = try LinearQuadraticQualificationFixture.analytic(), policy = try LinearQuadraticQualificationFixture.policy()
        let initial = try LinearQuadraticQualificationFixture.work(policy, seeded: true)
        let task = Task { () throws -> Void in
            var work = initial
            withUnsafeCurrentTask { $0?.cancel() }
            try LinearQuadraticQualificationCases.actualTaskCancellation(system, policy: policy, work: &work)
        }
        try await task.value
    }
}
