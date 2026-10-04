@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension LoadedCheckpointedMechanismSleep {
    @inline(never)
    public func stepWithLoads(_ session:any RuntimeSessionOperating,loadBudget:LoadBudget,maximumLoadInvocations:Int) throws(LoadedMechanismSleepFailure) -> LoadedMechanismAdvanceResult {
        let context=try prepareLoadedStep(session,loadBudget:loadBudget,maximumLoadInvocations:maximumLoadInvocations)
        return try integrateLoaded(session,adapter:context.adapter,execution:context.execution)
    }
    @inline(never)
    private func prepareLoadedStep(_ session:any RuntimeSessionOperating,loadBudget:LoadBudget,maximumLoadInvocations:Int) throws(LoadedMechanismSleepFailure) -> LoadedSleepStepContext {
        let source=session.snapshot(),execution:StationaryLoadExecution
        do throws(StationaryLoadError) { execution=try StationaryLoadExecution(scope:.equationExecution,budget:loadBudget,maximumInvocations:maximumLoadInvocations,requiredScalars:model.tree.layout.velocityCount) }
        catch { throw .preflight(error.runtimeFailure,accepted:source,loads:.notAdmitted(scope:.equationExecution,budget:loadBudget,maximumInvocations:maximumLoadInvocations)) }
        let adapter:LoadedSleepMechanismEquation
        do throws(RuntimeFailure) {
            guard source.checkpoint.acceptedSteps < UInt64.max,source.physical.stamp == model.stamp,let record=source.checkpoint.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Loaded accepted source/contributor is missing.") }
            adapter=try LoadedSleepMechanismEquation(owner:self,source:source,history:associated(record,physical:source.checkpoint.physical,sequence:source.checkpoint.acceptedSteps),execution:execution)
        } catch { throw .preflight(error,accepted:source,loads:execution.close()) }
        return LoadedSleepStepContext(adapter:adapter,execution:execution)
    }
    @inline(never)
    private func integrateLoaded(_ session:any RuntimeSessionOperating,adapter:LoadedSleepMechanismEquation,execution:StationaryLoadExecution) throws(LoadedMechanismSleepFailure) -> LoadedMechanismAdvanceResult {
        do throws(IntegrationFailure) {
            let actual=try ReferenceExplicitIntegrator().step(session,model:model,equations:adapter,continuation:continuation)
            return LoadedMechanismAdvanceResult(integration:actual,loads:execution.close())
        } catch { throw .integration(error,loads:execution.close()) }
    }
}
