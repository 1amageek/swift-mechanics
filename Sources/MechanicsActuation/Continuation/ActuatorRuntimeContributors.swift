import MechanicsModel
import MechanicsCompiler
import MechanicsRuntime
public struct ActuatorRuntimeContributors: RuntimeContributorHandling, ActuatorBindingLookingUp, Sendable {
    public let bindings:[ActuatorBinding]
    public let schemas:[RuntimeContributorSchema]
    public let codec:any ActuatorContinuationCoding
    public let controlBudget:ActuationBudget
    public init(bindings:[ActuatorBinding],codec:any ActuatorContinuationCoding,controlBudget:ActuationBudget,work:inout ActuationWork) throws(ActuationError) {
        guard bindings.count <= work.budget.maximumBindings,bindings.count <= controlBudget.maximumBindings else { throw .capacityExceeded }
        let (bytes,overflow)=bindings.count.multipliedReportingOverflow(by:MemoryLayout<RuntimeContributorSchema>.stride)
        guard !overflow else { throw .capacityExceeded };try work.reserve(bytes:bytes)
        var schemas:[RuntimeContributorSchema]=[];schemas.reserveCapacity(bindings.count)
        for i in bindings.indices {
            try work.metadata(bindings[i].actuator.key);try work.charge(1)
            for j in 0..<i { try work.charge(1);guard bindings[i].actuator != bindings[j].actuator else { throw .invalidInput } }
            let payloadSize=try codec.encodedSize(binding:bindings[i],work:&work)
            do { schemas.append(try RuntimeContributorSchema(id:bindings[i].actuator.key,category:.actuator,version:1,maximumBytes:payloadSize)) } catch { throw .runtime(error.code) }
        }
        self.bindings=bindings;self.schemas=schemas;self.codec=codec;self.controlBudget=controlBudget
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        let work:ActuationWork
        do throws(ActuationError) {
            var local=ActuationWork(budget:try limited(budget))
            let binding=try binding(id:record.id,work:&local)
            try binding.validate(model:model,work:&local);_=try codec.decode(record,binding:binding,work:&local)
            work=local
        } catch { throw failure(error,record:record.id) }
        return try RuntimeValidationEvidence(workUnitsUsed:work.used,scratchBytesUsed:work.peakBytes)
    }
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        do throws(ActuationError) {
            var work=ActuationWork(budget:try limited(budget))
            guard transition.compatibility == .preservesCoordinates,transition.target == target.stamp,transition.source.identity == transition.target.identity else { throw ActuationError.staleBinding }
            let binding=try binding(id:record.id,work:&work);try binding.validate(model:target,work:&work)
            let oldBinding=try ActuatorBinding(actuator:binding.actuator,joint:binding.joint,frame:binding.frame,model:transition.source,lawRevision:binding.lawRevision,continuationKey:binding.continuationKey,
                positionIndex:binding.positionIndex,velocityIndex:binding.velocityIndex,coordinate:binding.coordinate,authority:binding.authority,stateKind:binding.stateKind,stateDomain:binding.stateDomain)
            let old=try codec.decode(record,binding:oldBinding,work:&work)
            let new=try ActuatorState(binding:binding,time:old.time,primary:old.primary,secondary:old.secondary,mode:old.mode,sequence:old.sequence)
            return try codec.encode(new,work:&work)
        } catch { throw failure(error,record:record.id) }
    }
    private func limited(_ runtime:RuntimeValidationBudget) throws(ActuationError) -> ActuationBudget {
        try ActuationBudget(maximumWork:min(controlBudget.maximumWork,runtime.workUnits),maximumScalars:controlBudget.maximumScalars,
            maximumBytes:min(controlBudget.maximumBytes,runtime.scratchBytes),maximumBindings:controlBudget.maximumBindings,
            maximumMetadataBytes:controlBudget.maximumMetadataBytes,isCancelled:controlBudget.isCancelled)
    }
    public func binding(id:String,work:inout ActuationWork) throws(ActuationError) -> ActuatorBinding {
        try work.metadata(id)
        for binding in bindings { try work.metadata(binding.actuator.key);try work.charge(1);if binding.actuator.key == id { return binding } }
        throw .staleBinding
    }
    private func failure(_ error:ActuationError,record:String) -> RuntimeFailure { actuationRuntimeFailure(error,id:record) }
}
