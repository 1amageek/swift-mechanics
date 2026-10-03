import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsCompiler
import MechanicsRuntime
public struct FluidRuntimeContributors: RuntimeContributorHandling, Sendable {
    public let codec: any FluidContinuationCoding
    public init(codec: any FluidContinuationCoding) { self.codec=codec }
    public var schemas: [RuntimeContributorSchema] { [codec.schema] }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == codec.channel.model,model.descriptor.worldFrame == codec.channel.frame,
              model.descriptor.rootBase == .fixed,model.descriptor.rootAuthority == .fixed,
              model.descriptor.initialState.q.isEmpty,model.descriptor.initialState.v.isEmpty else {
            throw RuntimeFailure(.incompatibleModel,contributor:record.id,message:"Fluid requires its fixed-frame zero-coordinate carrier.")
        }
        var work:FluidByteWork
        do throws(FluidError) {
            work=try FluidByteWork(maximumBytes:budget.scratchBytes,maximumVisitedBytes:budget.workUnits)
            _ = try codec.decode(record,work:&work)
        } catch { throw fluidRuntimeFailure(error,id:record.id) }
        return try RuntimeValidationEvidence(workUnitsUsed:work.visitedBytes,scratchBytesUsed:work.peakBytes)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime model migration calls this requirement; fluid geometry/material reconciliation is not implemented. No migrated state may be published until physical-field/time conservation and changed-boundary admission are proved.
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                        budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.unsupportedDomain,contributor:record.id,message:"Fluid model migration is not qualified; same-context checkpoint replay is supported.")
    }
}
internal func fluidRuntimeFailure(_ error:FluidError,id:String) -> RuntimeFailure {
    let code:RuntimeFailureCode
    switch error {
    case .capacity: code = .contributorBudgetExceeded
    case .cancelled: code = .cancelled
    case .staleBinding: code = .incompatibleContinuation
    case .runtime(let actual): code=actual
    default: code = .invalidContributor
    }
    let unavailable: Bool
    if case .numerical(_, let unknown) = error { unavailable = unknown } else { unavailable = false }
    return RuntimeFailure(code,contributor:id,message:"Fluid physical or continuation operation rejected its input.", failedSupplierWorkUnavailable: unavailable)
}
