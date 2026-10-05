import SwiftMechanics
#if canImport(GeometryParametersQualificationSupport)
import GeometryParametersQualificationSupport
#endif
import Testing

@Suite struct GeometryParametersQualificationTests {
    @Test func literalSITranslationAndAdditiveBindings() throws { try GeometryParametersQualificationCases.rootTranslation() }
    @Test func rightBodyRootRotationAndMovingBias() throws { try GeometryParametersQualificationCases.rootRotation() }
    @Test func nonidentityParentAnchor() throws { try GeometryParametersQualificationCases.parentAnchor() }
    @Test func inverseChildAnchor() throws { try GeometryParametersQualificationCases.childAnchor() }
    @Test func normalizedRawScalarAxes() throws { try GeometryParametersQualificationCases.rawAxes() }
    @Test func sourceChartUnitsAndShapeRefusals() throws { try GeometryParametersQualificationCases.sourceRefusals() }
    @Test func exactWorkAndCallerCancellation() throws { try GeometryParametersQualificationCases.exactWorkAndCancellation() }
    @Test func declaredDomainsAndActualSupplierFailure() throws { try GeometryParametersQualificationCases.domainsAndSupplierFailure() }
    @Test(.timeLimit(.minutes(1))) func actualCancelledTask() async throws {
        let fixture = try GeometryParametersQualificationFixture()
        let source = fixture.source([]), policy = try GeometryParametersQualificationFixture.policy()
        let initialWork = try GeometryParametersQualificationFixture.work(seeded: true)
        let initialCalls = try DerivativeSupplierWork(maximumCalls: 100)
        let task = Task { () throws -> Void in
            var work = initialWork, calls = initialCalls
            withUnsafeCurrentTask { $0?.cancel() }
            try GeometryParametersQualificationCases.actualTaskCancellation(source, policy: policy, work: &work, supplierWork: &calls)
        }
        try await task.value
    }
}
