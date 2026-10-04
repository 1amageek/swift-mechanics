/// Contextual law and integration association precedes the lower accepted-state authority.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct GeometricMechanismCheckpointHandler: RuntimeCheckpointHandling, Sendable {
    public let equations:GeometricMechanismEquation
    public let continuation:IntegrationContinuationProvider
    public let validationBudget:NumericalBudget
    private let base:any RuntimeCheckpointHandling
    public init(equations:GeometricMechanismEquation,continuation:IntegrationContinuationProvider,
                base:any RuntimeCheckpointHandling,validationBudget:NumericalBudget) throws(RuntimeFailure) {
        guard equations.descriptor == continuation.descriptor,validationBudget.scalarStorage >= equations.contextualScalarStorage else {
            throw RuntimeFailure(.invalidInput,message:"Geometric contextual handler chart or capacity differs.")
        }
        self.equations=equations;self.continuation=continuation;self.base=base;self.validationBudget=validationBudget
    }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        if let cancellation { try cancellation.check() }
        try equations.validate(model:model)
        guard checkpoint.model == model.stamp,let record=checkpoint.contributors.first(where:{$0.id == continuation.schema.id}) else {
            throw RuntimeFailure(.invalidContributor,message:"Geometric contextual continuation absent.")
        }
        var work=NumericalWork(budget:validationBudget)
        do throws(NumericalError) {
            try work.requireStorage(equations.contextualScalarStorage)
            try work.chargeOperations(try NumericalWork.sum(1,try NumericalWork.sum(record.bytes.count,equations.descriptor.chart.utf8.count)))
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Geometric contextual admission budget exhausted.") }
        try equations.validatePrescribed(checkpoint.physical,work:&work)
        try equations.validateStoredPhysical(checkpoint.physical,acceptedSteps:checkpoint.acceptedSteps,work:&work)
        let history=try continuation.associatedHistory(record,physical:checkpoint.physical,equations:equations)
        guard history.acceptedSteps == checkpoint.acceptedSteps else { throw RuntimeFailure(.invalidContributor,message:"Geometric physical/history sequence differs.") }
        if let cancellation { try cancellation.check() }
        return try base.admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): A new model or trajectory law needs explicit physical reconciliation and new contextual continuation. Record-only migration cannot preserve imposed motion authority.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Geometric law-bound continuation requires explicit reinitialization.")
    }
}
