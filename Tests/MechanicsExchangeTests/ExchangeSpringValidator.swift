import MechanicsCompiler
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
struct ExchangeSpringValidator: MechanicalExtensionValidating {
    let registrations:[ValidatorRegistration]
    init() throws {
        registrations=[try ValidatorRegistration(schema:"spring.v1",feature:"spring.descriptor",owner:"exchange-fixture",evidenceRevision:"v1",operation:.descriptorValidation)]
    }
    func validate(_ record:MechanicalExtensionRecord,context:ExtensionValidationContext,budget:NumericalBudget) throws(CompilationFailure) -> ExtensionValidationEvidence {
        guard record.schema == "spring.v1",record.references.count == 2,
              record.references.allSatisfy({ reference in context.descriptor.bodies.contains { $0.id == reference } }),record.parameters.count == 2,
              let stiffness=record.parameters.first(where:{$0.name == "stiffness"}),stiffness.value > 0,stiffness.dimension == PhysicalDimension(mass:1,time:-2),
              let length=record.parameters.first(where:{$0.name == "restLength"}),length.value >= 0,length.dimension == .length else {
            throw .one(.invalidLawDomain,.extensionValidation,records:[record.id],message:"Spring input must retain its body references and positive SI stiffness/nonnegative rest length.")
        }
        var work=NumericalWork(budget:budget)
        do { try work.requireStorage(2);try work.chargeOperations(12) } catch { throw .one(.validatorBudgetExceeded,.extensionValidation,message:"Spring descriptor budget exhausted.") }
        return ExtensionValidationEvidence(feature:"spring.descriptor",dependencies:record.references.map { ParameterReference(entity:$0,aspect:.bodyPlacement) },work:work)
    }
}
