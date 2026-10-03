import MechanicsNumerics

public struct NoMechanicalExtensions: MechanicalExtensionValidating, Sendable {
    public init() {}
    public var registrations: [ValidatorRegistration] { [] }

    public func validate(_ record: MechanicalExtensionRecord, context: ExtensionValidationContext,
                         budget: NumericalBudget) throws(CompilationFailure) -> ExtensionValidationEvidence {
        throw .one(.unknownSchema, .extensionValidation, records: [record.id], message: "No extension schemas are registered.")
    }
}
