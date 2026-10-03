import MechanicsNumerics

public protocol MechanicalExtensionValidating: Sendable {
    var registrations: [ValidatorRegistration] { get }
    func validate(_ record: MechanicalExtensionRecord, context: ExtensionValidationContext,
                  budget: NumericalBudget) throws(CompilationFailure) -> ExtensionValidationEvidence
}
