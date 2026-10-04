public struct ScalarActuatorTopologyMigration: Sendable {
    public let source: ActuatorState
    public let target: ActuatorState
    public let record: RuntimeContributorState
    public let provider: ActuatorRuntimeContributors
    private init(source:ActuatorState,target:ActuatorState,record:RuntimeContributorState,provider:ActuatorRuntimeContributors) {
        self.source=source;self.target=target;self.record=record;self.provider=provider
    }
    public static func prepare(record:RuntimeContributorState,binding:ActuatorBinding,release:SubtreeRelease,
                               controlBudget:ActuationBudget,work:inout ActuationWork) throws(TopologyReleaseFailure) -> ScalarActuatorTopologyMigration {
        guard binding.model == release.source.stamp,
              let mapping=release.mappings.first(where: { $0.joint == binding.joint }),
              mapping.source.positions.count == 1,mapping.source.velocities.count == 1,
              mapping.target.positions.count == 1,mapping.target.velocities.count == 1,
              mapping.source.positions.start == binding.positionIndex,mapping.source.velocities.start == binding.velocityIndex,
              let old=release.sourceModel.descriptor.joints.first(where: { $0.record.id == binding.joint }),
              let next=release.target.descriptor.joints.first(where: { $0.record.id == binding.joint }),old == next else { throw .unsupportedDomain }
        let codec=FixedActuatorContinuationCodec()
        let source=try guarded(&work) { (ledger:inout ActuationWork) throws(ActuationError) in
            try binding.validate(model:release.sourceModel,work:&ledger)
            return try codec.decode(record,binding:binding,work:&ledger)
        }
        guard source.time == release.source.state.time else { throw .staleSource }
        let newBinding:ActuatorBinding,target:ActuatorState
        do throws(ActuationError) {
            newBinding=try ActuatorBinding(actuator:binding.actuator,joint:binding.joint,frame:binding.frame,model:release.target.stamp,
                lawRevision:binding.lawRevision,continuationKey:binding.continuationKey,positionIndex:mapping.target.positions.start,
                velocityIndex:mapping.target.velocities.start,coordinate:binding.coordinate,authority:binding.authority,
                stateKind:binding.stateKind,stateDomain:binding.stateDomain)
            target=try ActuatorState(binding:newBinding,time:source.time,primary:source.primary,secondary:source.secondary,mode:source.mode,sequence:source.sequence)
        } catch { throw .actuation(error) }
        let bytes=try guarded(&work) { (ledger:inout ActuationWork) throws(ActuationError) in try codec.encode(target,work:&ledger) }
        let decoded=try guarded(&work) { (ledger:inout ActuationWork) throws(ActuationError) in try codec.decode(bytes,binding:newBinding,work:&ledger) }
        guard decoded == target else { throw .originalAcceptance }
        let provider=try guarded(&work) { (ledger:inout ActuationWork) throws(ActuationError) in
            try ActuatorRuntimeContributors(bindings:[newBinding],codec:codec,controlBudget:controlBudget,work:&ledger)
        }
        return ScalarActuatorTopologyMigration(source:source,target:target,record:bytes,provider:provider)
    }
    private static func guarded<T>(_ work:inout ActuationWork,_ body:(inout ActuationWork) throws(ActuationError) -> T) throws(TopologyReleaseFailure) -> T {
        guard !Task.isCancelled,!work.budget.isCancelled() else { throw .cancelled }
        do throws(ActuationError) { try work.charge(1) } catch { throw .actuation(error) }
        let before=work
        let result:T
        do throws(ActuationError) { result=try body(&work) }
        catch { guard preserved(before,work) else { work=before;throw .supplierWorkUnavailable };throw .actuation(error) }
        guard preserved(before,work) else { work=before;throw .supplierWorkUnavailable }
        guard !Task.isCancelled,!before.budget.isCancelled() else { throw .cancelled };return result
    }
    private static func preserved(_ a:ActuationWork,_ b:ActuationWork) -> Bool {
        let x=a.budget,y=b.budget
        return x.maximumWork == y.maximumWork && x.maximumScalars == y.maximumScalars && x.maximumBytes == y.maximumBytes
            && x.maximumBindings == y.maximumBindings && x.maximumMetadataBytes == y.maximumMetadataBytes
            && b.used >= a.used && b.peakScalars >= a.peakScalars && b.peakBytes >= a.peakBytes
    }
}
