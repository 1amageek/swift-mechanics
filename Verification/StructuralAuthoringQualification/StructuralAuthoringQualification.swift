#if canImport(StructuralAuthoringQualificationSupport)
import StructuralAuthoringQualificationSupport
#endif

@main
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct StructuralAuthoringQualification {
    static func main() throws {
        try StructuralAuthoringQualificationCases.declarationLayoutAndIdentity()
        try StructuralAuthoringQualificationCases.signedPhaseAndFrames()
        try StructuralAuthoringQualificationCases.realMechanismAndReaction()
        try StructuralAuthoringQualificationCases.passiveLoadedEnergy()
        try StructuralAuthoringQualificationCases.typedPhysicalRefusals()
        try StructuralAuthoringQualificationCases.capacitiesAndRetainedWork()
        try StructuralAuthoringQualificationCases.scopeAndLegacyCleanup()
        print("Structural authoring: seven public physical/refusal/resource cases passed.")
    }
}
