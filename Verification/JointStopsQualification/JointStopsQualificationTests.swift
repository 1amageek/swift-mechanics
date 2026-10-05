import SwiftMechanics
#if canImport(JointStopsQualificationSupport)
import JointStopsQualificationSupport
#endif
import Testing

@Suite struct JointStopsQualificationTests {
    @Test func coupledOriginalLowerBoundary() throws { try JointStopQualificationCases.coupledLowerBoundary() }
    @Test func signedUpperElasticAndLowerPlastic() throws { try JointStopQualificationCases.upperElasticAndLowerPlastic() }
    @Test func rotarySIStopMetricAndThreshold() throws { try JointStopQualificationCases.rotaryMetricAndThreshold() }
    @Test func signedBoundaryRefusals() throws { try JointStopQualificationCases.signedBoundaryRefusals() }
    @Test func sourceUnitsAndUnsupportedDomains() throws { try JointStopQualificationCases.sourceUnitAndUnsupportedRefusals() }
    @Test func boundedWorkAndSuppliedCancellation() throws { try JointStopQualificationCases.boundedWorkAndCancellation() }
    @Test func originalSupplierFailureAndLedger() throws { try JointStopQualificationCases.supplierFailureAndLedger() }
    @Test(.timeLimit(.minutes(1))) func cancelledTaskPublishesNoImpact() async throws {
        let fixture = try JointStopQualificationFixture(specification: .prismatic(axis: .unitX))
        let input = try fixture.input(position: [0], velocity: [-2]), policy = try fixture.policy()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try JointStopQualificationCases.actualTaskCancellation(input: input, policy: policy)
        }
        try await task.value
    }
}
