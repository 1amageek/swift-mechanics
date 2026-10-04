/// Strict original quadratic physical and continuation admission, including sequence zero.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct NonlinearMechanismCheckpointHandler: RuntimeCheckpointHandling, Sendable {
    public let equations:NonlinearMechanismEquation
    public let continuation:IntegrationContinuationProvider
    public let validationBudget:NumericalBudget
    private let base:any RuntimeCheckpointHandling
    public init(equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,
                base:any RuntimeCheckpointHandling,validationBudget:NumericalBudget) throws(RuntimeFailure) {
        guard equations.hasPhysicalSourceBinding,equations.descriptor == continuation.descriptor,
              validationBudget.scalarStorage >= equations.contextualScalarStorage else {
            throw RuntimeFailure(.invalidInput,message:"Quadratic contextual source, chart or capacity differs.")
        }
        self.equations=equations;self.continuation=continuation;self.base=base;self.validationBudget=validationBudget
    }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        if let cancellation { try cancellation.check() };try equations.checkColdCancellation()
        try equations.validate(model:model)
        guard checkpoint.model == model.stamp,checkpoint.contributors.count <= configuration.capacity.maximumContributors else {
            throw RuntimeFailure(.invalidContributor,message:"Quadratic checkpoint source or catalog capacity differs.")
        }
        var work=NumericalWork(budget:validationBudget)
        do throws(NumericalError) {
            try work.requireStorage(equations.contextualScalarStorage)
            try work.chargeOperations(try NumericalWork.sum(1,checkpoint.contributors.count))
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Quadratic contextual catalog admission exhausted.") }
        var found:RuntimeContributorState?
        for record in checkpoint.contributors where record.id == continuation.schema.id {
            guard found == nil,record.bytes.count <= continuation.schema.maximumBytes,
                  record.bytes.count <= configuration.capacity.maximumContributorBytes else {
                throw RuntimeFailure(.invalidContributor,message:"Quadratic continuation is duplicated or exceeds its admitted bounds.")
            }
            found=record
        }
        guard let record=found else { throw RuntimeFailure(.invalidContributor,message:"Quadratic continuation is missing.") }
        do throws(NumericalError) {
            try work.chargeOperations(try NumericalWork.sum(record.bytes.count,try NumericalWork.sum(equations.descriptor.chart.utf8.count,equations.descriptor.dimensions.count)))
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Quadratic contextual admission budget exhausted.") }
        try equations.validateStoredPhysical(checkpoint.physical,work:&work,cancellation:cancellation)
        let history=try continuation.associatedHistory(record,physical:checkpoint.physical,equations:equations)
        guard history.acceptedSteps == checkpoint.acceptedSteps,history.acceptedTime.bitPattern == checkpoint.physical.time.bitPattern,
              history.acceptedPoint.count == checkpoint.physical.q.count+checkpoint.physical.v.count else {
            throw RuntimeFailure(.invalidContributor,message:"Quadratic physical/history time or global sequence differs.")
        }
        for i in checkpoint.physical.q.indices {
            guard history.acceptedPoint[i].bitPattern == checkpoint.physical.q[i].bitPattern else { throw RuntimeFailure(.invalidContributor,message:"Quadratic history position bits differ.") }
        }
        for i in checkpoint.physical.v.indices {
            guard history.acceptedPoint[checkpoint.physical.q.count+i].bitPattern == checkpoint.physical.v[i].bitPattern else { throw RuntimeFailure(.invalidContributor,message:"Quadratic history velocity bits differ.") }
        }
        if let cancellation { try cancellation.check() };try equations.checkColdCancellation()
        return try base.admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Record-only migration has no original target rows/force or catalog reconciliation authority.
    // Actual quadratic topology publication must supply reconciled physical evidence and explicit target continuation before success.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Quadratic source-bound migration requires explicit physical reconciliation.")
    }
}
