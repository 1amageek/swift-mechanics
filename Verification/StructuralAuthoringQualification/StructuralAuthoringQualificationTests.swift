import SwiftMechanics
#if canImport(StructuralAuthoringQualificationSupport)
import StructuralAuthoringQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct StructuralAuthoringQualificationTests {
    @Test func declaredOriginalLayoutAndIdentity() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.declarationLayoutAndIdentity()
    }
    @Test func actualSignedPhaseAndFrames() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.signedPhaseAndFrames()
    }
    @Test func realEquationEvolutionAndReaction() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.realMechanismAndReaction()
    }
    @Test func originalPassiveLoadedEnergy() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.passiveLoadedEnergy()
    }
    @Test func explicitPhysicalRefusals() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.typedPhysicalRefusals()
    }
    @Test func capacitiesAndRetainedSupplierWork() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.capacitiesAndRetainedWork()
    }
    @Test func independentScopesAndLegacyCleanup() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        try StructuralAuthoringQualificationCases.scopeAndLegacyCleanup()
    }
    @Test func actualCancelledTask() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { throw StructuralAuthoringQualificationError.assertion("Required physical consumer API is unavailable") }
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try StructuralAuthoringQualificationCases.cancelledTask()
        }
        try await task.value
    }
}
