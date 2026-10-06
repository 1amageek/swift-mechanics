@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct SleepTopologyCatalogAssembly {
    let records:[RuntimeContributorState]
    let registry:TopologyRuntimeContributors
    init(source:RuntimeAcceptedState,retirement:PreparedSleepTopologyRetirement,transition:NonlinearReconciledSubtreeRelease,
         history:TopologyHistoryContributor,wake:SleepTopologyWakeContributor,dispositions:[SleepTopologyContributorDisposition],
         equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,configuration:RuntimeConfiguration,
         work:inout NumericalWork) throws(TopologyReleaseFailure) {
        var records:[RuntimeContributorState]=[],providers:[any RuntimeContributorHandling]=[],seen:Set<String>=[]
        for disposition in dispositions {
            let id:String
            switch disposition {
            case .appendHistory:id=history.schema.id
            case .retireSleep:id=retirement.sleepRecord.id
            case .initializeGlobalIntegration(let value):id=value
            case .preserve(let value,_):id=value
            }
            try TopologyArithmetic.charge(1,&work)
            guard seen.insert(id).inserted,let record=source.checkpoint.contributors.first(where:{$0.id == id}) else { throw .staleSource }
            try TopologyArithmetic.charge(record.bytes.count,&work)
            switch disposition {
            case .appendHistory:
                guard record.id == history.schema.id else { throw .staleSource };records.append(history.record);providers.append(history)
            case .retireSleep:
                guard record == retirement.sleepRecord else { throw .staleSource };records.append(wake.record);providers.append(wake)
            case .initializeGlobalIntegration:
                guard record.category == .integrator,record.id == continuation.schema.id else { throw .unsupportedDomain }
                records.append(try Self.integration(continuation,equations:equations,physical:transition.physical,
                    steps:source.checkpoint.acceptedSteps+1,work:&work));providers.append(continuation)
            case .preserve(_,let validator):
                // FIXME(INCOMPLETE_IMPLEMENTATION): These supplier histories have no selected zero-load topology/law migration proof.
                // Explicit producer migration must qualify before carrying their records to a released model.
                guard record.category != .actuator,record.category != .integrator,record.category != .constitutive,
                      record.id != "mechanics.hybrid.events.v1",!record.id.hasPrefix("mechanics.mechanism.sleep"),
                      record.id != "mechanics.mechanisms.break.v1",record.id != history.schema.id,
                      validator.schemas.count == 1,validator.schemas[0].id == record.id else { throw .unsupportedDomain }
                records.append(record);providers.append(validator)
            }
        }
        guard seen.count == source.checkpoint.contributors.count,
              records.contains(history.record),records.contains(wake.record),records.contains(where:{$0.id == continuation.schema.id}) else { throw .staleSource }
        do throws(RuntimeFailure) {
            registry=try TopologyRuntimeContributors(providers:providers,capacity:configuration.capacity)
            guard registry.schemas == configuration.requiredContributors,records.count == registry.schemas.count else {
                throw RuntimeFailure(.missingContributor,message:"Selected topology target schemas differ from its exact produced catalog.")
            }
        } catch { throw .runtime(error) }
        self.records=records.sorted {$0.id < $1.id}
    }
    @inline(never)
    private static func integration(_ provider:IntegrationContinuationProvider,equations:NonlinearMechanismEquation,
                                    physical:KinematicState,steps:UInt64,work:inout NumericalWork) throws(TopologyReleaseFailure) -> RuntimeContributorState {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Adaptive target history has no admitted inherited error/controller initialization.
        // This selected accepted topology boundary supports the explicitly configured RK4 initialization only.
        guard provider.policy.method == .classicalRK4,provider.descriptor == equations.descriptor else { throw .unsupportedDomain }
        try TopologyArithmetic.charge(provider.schema.maximumBytes,&work)
        do throws(RuntimeFailure) {
            let initial=try provider.initialRecord(physical:physical,equations:equations),history=try provider.history(initial)
            let record=try provider.record(acceptedTime:history.acceptedTime,point:history.acceptedPoint,
                nextStep:history.nextStep,acceptedSteps:steps,normalizedError:nil)
            let bound=try provider.associatedHistory(record,physical:physical,equations:equations)
            guard bound.acceptedSteps == steps else { throw RuntimeFailure(.invalidContributor,message:"Topology integration global sequence differs.") }
            return record
        } catch { throw .runtime(error) }
    }
}
