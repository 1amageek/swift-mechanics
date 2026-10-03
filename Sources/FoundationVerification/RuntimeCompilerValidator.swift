import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCompiler

struct RuntimeCompilerValidator: MechanicalExtensionValidating {
    let registrations: [ValidatorRegistration]

    init() throws(CompilationFailure) {
        registrations = [try ValidatorRegistration(schema: "probe.stiffness", feature: "probe.stiffness.validation",
            owner: "FoundationVerification", evidenceRevision: "probe-1", operation: .descriptorValidation)]
    }

    func validate(_ record: MechanicalExtensionRecord, context: ExtensionValidationContext,
                  budget: NumericalBudget) throws(CompilationFailure) -> ExtensionValidationEvidence {
        guard record.schema == "probe.stiffness", record.references.count == 1,
              context.descriptor.bodies.contains(where: { $0.id == record.references[0] }),
              record.parameters.count == 1, record.parameters[0].name == "stiffness",
              record.parameters[0].value > 0,
              record.parameters[0].dimension == PhysicalDimension(mass: 1, time: -2) else {
            throw .one(.invalidLawDomain, .extensionValidation, records: [record.id], message: "Invalid positive SI stiffness descriptor.")
        }
        var work = NumericalWork(budget: budget)
        do { try work.requireStorage(1); try work.chargeOperations(12) }
        catch { throw .one(.validatorBudgetExceeded, .extensionValidation, records: [record.id], message: "Descriptor validation exceeded its supplied budget.") }
        return ExtensionValidationEvidence(feature: "probe.stiffness.validation",
            dependencies: [ParameterReference(entity: record.references[0], aspect: .bodyMode)], work: work)
    }
}
