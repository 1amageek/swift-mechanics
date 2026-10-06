import SwiftMechanics
#if canImport(URDFQualificationSupport)
import URDFQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct URDFQualificationTests {
    @Test func suppliedRotatedFullInertiaAndActualMotion() throws { try URDFQualificationCases.rotatedInertiaAndMotion() }
    @Test func actualEquationsWithIndependentPhysicalOracle() throws { try URDFQualificationCases.actualRigidEquations() }
    @Test func actualMovingColliderAndOriginalWitness() throws { try URDFQualificationCases.movingAnalyticCollision() }
    @Test func explicitSIRootVariantsAndNoInventedDynamics() throws { try URDFQualificationCases.rootVariantsAndUnavailableDynamics() }
    @Test func independentOriginalExportBytesAndLosses() throws { try URDFQualificationCases.originalExportAndLosses() }
    @Test func originalTypedSemanticAndLawRefusals() throws { try URDFQualificationCases.semanticRefusals() }
    @Test func originalCapacitiesAndRetainedWork() throws { try URDFQualificationCases.capacitiesAndReceipts() }
    @Test func actualCancelledTaskRefusesEveryPublicPath() async throws {
        let result = try URDFQualificationCases.cancellationResult()
        let state = try result.model.makeState(result.model.descriptor.initialState)
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try URDFQualificationCases.cancelledTask(result, state: state)
        }
        try await task.value
    }
}
