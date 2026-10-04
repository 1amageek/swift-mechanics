import SwiftMechanics

struct SpringDescriptorValidator: MechanicalExtensionValidating {
    let registrations: [ValidatorRegistration]
    let forgedFeature: Bool
    init(registrationCount: Int = 1, operation: FeatureOperation = .descriptorValidation, forgedFeature: Bool = false) throws {
        registrations = try Array(repeating: ValidatorRegistration(schema: "spring", feature: "spring.descriptor", owner: "fixture", evidenceRevision: "fixture-1", operation: operation), count: registrationCount)
        self.forgedFeature = forgedFeature
    }
    func validate(_ record: MechanicalExtensionRecord, context: ExtensionValidationContext,
                  budget: NumericalBudget) throws(CompilationFailure) -> ExtensionValidationEvidence {
        guard record.schema == "spring", record.references.count == 2,
              record.references.allSatisfy({ reference in context.descriptor.bodies.contains { $0.id == reference } }),
              let stiffness = record.parameters.first(where: { $0.name == "stiffness" }),
              let restLength = record.parameters.first(where: { $0.name == "restLength" }),
              record.parameters.count == 2, stiffness.value > 0, restLength.value >= 0,
              stiffness.dimension == PhysicalDimension(mass: 1, time: -2), restLength.dimension == .length else {
            throw .one(.invalidLawDomain, .extensionValidation, records: [record.id], message: "Spring descriptor requires body endpoints, positive SI stiffness and nonnegative length.")
        }
        var work = NumericalWork(budget: budget)
        do { try work.requireStorage(2); try work.chargeOperations(12) }
        catch { throw .one(.validatorBudgetExceeded, .extensionValidation, records: [record.id], message: "Spring domain validation exceeded its supplied budget.") }
        return ExtensionValidationEvidence(feature: forgedFeature ? "invented.feature" : "spring.descriptor",
            dependencies: record.references.map { ParameterReference(entity: $0, aspect: .bodyPlacement) }, work: work)
    }
}
