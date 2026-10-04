@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceTopologyTransitionPreparer: TopologyTransitionPreparing {
    public init() {}
    @inline(never)
    public func prepare(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,transition:ReconciledSubtreeRelease,
                        history:TopologyHistoryContributor,observation:TopologyReleaseObservation,ruleID:UInt64,
                        dispositions:[TopologyContributorDisposition],targetConfiguration:RuntimeConfiguration,
                        work:inout NumericalWork,actuationWork:inout ActuationWork) throws(TopologyReleaseFailure) -> PreparedTopologyPublication {
        guard !Task.isCancelled else { throw .cancelled }
        let release=transition.release,cap=targetConfiguration.capacity
        guard source.physical == release.source,source.checkpoint.physical == release.source.state,
              transition.physical.revision == release.target.stamp.revision,transition.physical.time == source.physical.state.time,
              transition.physical.q == release.incomingPhysical.q,transition.physical.v == release.incomingPhysical.v,
              source.checkpoint.contributors.count == sourceConfiguration.requiredContributors.count,
              sourceConfiguration.capacity == cap,sourceConfiguration.continuation == targetConfiguration.continuation,
              sourceConfiguration.determinism == targetConfiguration.determinism,
              source.checkpoint.continuation == sourceConfiguration.continuation,
              source.checkpoint.acceptedSteps < UInt64.max,
              dispositions.count == source.checkpoint.contributors.count,dispositions.count <= cap.maximumContributors else { throw .staleSource }
        try TopologyArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.product(128,cap.maximumContributors)) }
        var seen:Set<String>=[]
        for disposition in dispositions {
            try TopologyArithmetic.charge(1,&work)
            guard disposition.sourceID.utf8.count <= cap.maximumMetadataBytes,seen.insert(disposition.sourceID).inserted,
                  source.checkpoint.contributors.contains(where: { $0.id == disposition.sourceID }) else { throw .staleSource }
        }
        for (record,schema) in zip(source.checkpoint.contributors,sourceConfiguration.requiredContributors) {
            guard record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count <= schema.maximumBytes else { throw .staleSource }
        }
        let nextHistory=try history.appending(source:source,target:transition,observation:observation,ruleID:ruleID)
        var records:[RuntimeContributorState]=[],providers:[any RuntimeContributorHandling]=[],actuators:[ScalarActuatorTopologyMigration]=[]
        for disposition in dispositions {
            guard let record=source.checkpoint.contributors.first(where: { $0.id == disposition.sourceID }) else { throw .staleSource }
            try TopologyArithmetic.charge(record.bytes.count,&work)
            switch disposition {
            case .appendHistory:
                guard record == history.record else { throw .staleSource };records.append(nextHistory.record);providers.append(nextHistory)
            case .preserve(_,let validator):
                // FIXME(INCOMPLETE_IMPLEMENTATION): These producers have no topology/law-history migration certificate.
                // Their original record cannot be admitted by generic preservation or reset after a cut.
                guard record.category != .actuator,record.category != .integrator,
                      record.id != "mechanics.hybrid.events.v1",record.id != "mechanics.mechanism.sleep.v1",
                      record.id != "mechanics.mechanisms.break.v1",record.id != history.schema.id,
                      validator.schemas.count == 1,validator.schemas[0].id == record.id else { throw .unsupportedDomain }
                records.append(record);providers.append(validator)
            case .migrateScalarActuator(let binding,let budget):
                guard record.category == .actuator else { throw .unsupportedDomain }
                let migration=try ScalarActuatorTopologyMigration.prepare(record:record,binding:binding,release:release,controlBudget:budget,work:&actuationWork)
                records.append(migration.record);providers.append(migration.provider);actuators.append(migration)
            case .initializeIntegration(_,let provider,let equations):
                guard record.category == .integrator,provider.descriptor.model == release.target.stamp else { throw .unsupportedDomain }
                let newRecord:RuntimeContributorState
                do throws(RuntimeFailure) {
                    newRecord=try provider.initialRecord(physical:transition.physical,equations:equations)
                    _=try provider.associatedHistory(newRecord,physical:transition.physical,equations:equations)
                } catch { throw .runtime(error) }
                records.append(newRecord);providers.append(provider)
            }
        }
        guard providers.contains(where: { $0.schemas == nextHistory.schemas }) else { throw .staleSource }
        let registry:TopologyRuntimeContributors,checkpoint:RuntimeCheckpoint
        do throws(RuntimeFailure) {
            registry=try TopologyRuntimeContributors(providers:providers,capacity:cap)
            guard registry.schemas == targetConfiguration.requiredContributors,records.count == registry.schemas.count else {
                throw RuntimeFailure(.missingContributor,message:"Target topology catalog is incomplete or differs from explicit required schemas.")
            }
            checkpoint=try RuntimeCheckpoint(model:release.target.stamp,continuation:targetConfiguration.continuation,
                physical:transition.physical,contributors:records,random:source.checkpoint.random,acceptedSteps:source.checkpoint.acceptedSteps+1)
        } catch { throw .runtime(error) }
        let handler=TopologyCheckpointHandler(history:nextHistory,contributors:registry)
        do throws(RuntimeFailure) {
            let admitted=try handler.admit(checkpoint,model:release.target,configuration:targetConfiguration,cancellation:nil)
            guard admitted.physical.state == transition.physical,admitted.checkpoint.random == source.checkpoint.random,
                  admitted.checkpoint.acceptedSteps == source.checkpoint.acceptedSteps+1,
                  admitted.checkpoint.contributors == records.sorted(by: { $0.id < $1.id }) else { throw RuntimeFailure(.invalidOwnerAccess,message:"Target catalog admission altered the prepared physical/history prefix.") }
        } catch { throw .runtime(error) }
        guard !Task.isCancelled else { throw .cancelled }
        return PreparedTopologyPublication(admission:_TopologyPublicationAdmission(source:source,sourceConfiguration:sourceConfiguration,
            transition:transition,configuration:targetConfiguration,contributors:records,handler:handler,actuators:actuators))
    }
    public func publish(_ prepared:PreparedTopologyPublication,session:any RuntimeModelReplacing) throws(TopologyReleaseFailure) -> RuntimeAcceptedState {
        guard !Task.isCancelled else { throw .cancelled }
        guard session.snapshot() == prepared.source else { throw .staleSource }
        let request=RuntimeModelReplacement(expectedSource:prepared.source.checkpoint,model:prepared.transition.release.target,
            physical:prepared.transition.physical,contributors:prepared.contributors,configuration:prepared.configuration,checkpoints:prepared.handler)
        do throws(RuntimeFailure) { return try session.replaceModel(request) } catch { throw .runtime(error) }
    }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct _TopologyPublicationAdmission: Sendable {
    let source:RuntimeAcceptedState;let sourceConfiguration:RuntimeConfiguration;let transition:ReconciledSubtreeRelease
    let configuration:RuntimeConfiguration;let contributors:[RuntimeContributorState];let handler:TopologyCheckpointHandler
    let actuators:[ScalarActuatorTopologyMigration]
    fileprivate init(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,transition:ReconciledSubtreeRelease,
                     configuration:RuntimeConfiguration,contributors:[RuntimeContributorState],handler:TopologyCheckpointHandler,actuators:[ScalarActuatorTopologyMigration]) {
        self.source=source;self.sourceConfiguration=sourceConfiguration;self.transition=transition;self.configuration=configuration
        self.contributors=contributors;self.handler=handler;self.actuators=actuators
    }
}
