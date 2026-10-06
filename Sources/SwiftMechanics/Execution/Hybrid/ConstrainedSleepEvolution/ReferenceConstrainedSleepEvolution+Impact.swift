@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ReferenceConstrainedSleepEvolution {
    @inline(never)
    internal func impactPublication(_ source:ConstrainedSleepSource,endpoint:IslandSleepTrajectoryEndpoint,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> ConstrainedSleepPublication {
        guard source.history.impactCount < UInt64(continuation.policy.maximumEvents),endpoint.physical.time>source.accepted.checkpoint.physical.time else { throw .hybrid(.capacityExceeded) }
        let result=try actualImpact(endpoint,work:&work,cancellation:cancellation)
        let wake:PreparedIslandImpactWake
        do throws(IslandSleepFailure) { wake=try sleep.prepareImpactWake(source:source.accepted,endpoint:endpoint,impact:result,work:&work.islands) } catch { throw .sleep(error) }
        try check(cancellation)
        let event:RuntimeContributorState
        do throws(RuntimeFailure) { event=try continuation.impactRecord(source:source.accepted.checkpoint,wake:wake,work:&work.numerical) } catch { throw .runtime(error) }
        return ConstrainedSleepPublication(source:source.accepted.checkpoint,physical:wake.physical,records:[wake.integration,wake.sleep,event],impact:result)
    }
    @inline(never)
    private func actualImpact(_ endpoint:IslandSleepTrajectoryEndpoint,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> ConstrainedNormalImpulseResult {
        let input=try inputContext(endpoint,work:&work,cancellation:cancellation)
        return try solve(prepare(input,work:&work,cancellation:cancellation),work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func inputContext(_ endpoint:IslandSleepTrajectoryEndpoint,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> ConstrainedSleepImpactInput {
        let input=try ConstrainedSleepInvocation.collision(&work) { (receipt:inout CollisionWork) throws(HybridError) in try environment.impactInput(endpoint:endpoint,eventIDs:environment.catalog.eventIDs,work:&receipt,cancellation:cancellation) }
        guard input.model.stamp == sleep.model.stamp,input.model.descriptor == sleep.model.descriptor,input.model.policy == sleep.model.policy,input.physical.state == endpoint.physical,input.expectedCollisionRevision == environment.catalog.geometryRevision,input.contacts.count == 1,input.contacts[0].eventID == environment.catalog.eventIDs[0] else { throw .hybrid(.staleModel) }
        return ConstrainedSleepImpactInput(input)
    }
    @inline(never)
    private func prepare(_ context:ConstrainedSleepImpactInput,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> PreparedConstrainedImpact {
        try check(cancellation)
        do throws(NumericalError) { try work.numerical.requireStorage(1);try work.numerical.chargeOperations(1) } catch { throw .hybrid(.numerical(error)) }
        do throws(LoadError) { try work.loads.reserve(scalars:1);try work.loads.charge(1) } catch { throw .load(error) }
        let known=work.numerical,knownLoads=work.loads,output:PreparedConstrainedImpact
        do throws(ConstrainedImpactError) { output=try preparing.prepare(input:context.input,constraints:sleep.program.constraints,policy:environment.impactPolicy,admission:sleep.program.policy.admission,loadWork:&work.loads,work:&work.numerical,cancellation:cancellation) }
        catch { if !ConstrainedSleepInvocation.valid(work.numerical,known) || !ConstrainedSleepInvocation.valid(work.loads,knownLoads) { work.numerical=known;work.loads=knownLoads;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(.impact(error)) };throw .impact(error) }
        guard ConstrainedSleepInvocation.valid(work.numerical,known),ConstrainedSleepInvocation.valid(work.loads,knownLoads),work.numerical.operations>known.operations else { work.numerical=known;work.loads=knownLoads;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(nil) }
        try check(cancellation);return output
    }
    @inline(never)
    private func solve(_ prepared:PreparedConstrainedImpact,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> ConstrainedNormalImpulseResult {
        do throws(NumericalError) { try work.numerical.requireStorage(1);try work.numerical.chargeOperations(1) } catch { throw .hybrid(.numerical(error)) }
        do throws(ContactLawError) { try work.contact.consume(operations:1,scalarStorage:1,records:1) } catch { throw .hybrid(.contact(error)) }
        let known=work.numerical,knownContact=work.contact,output:ConstrainedNormalImpulseResult
        do throws(ConstrainedImpactError) { output=try impulses.solve(prepared,work:&work.numerical,contactWork:&work.contact,cancellation:cancellation) }
        catch { if !ConstrainedSleepInvocation.valid(work.numerical,known) || !ConstrainedSleepInvocation.valid(work.contact,knownContact) { work.numerical=known;work.contact=knownContact;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(.impact(error)) };throw .impact(error) }
        guard ConstrainedSleepInvocation.valid(work.numerical,known),ConstrainedSleepInvocation.valid(work.contact,knownContact),work.numerical.operations>known.operations,output.source === prepared else { work.numerical=known;work.contact=knownContact;work.failedSupplierWorkUnavailable=true;throw .supplierLedgerFailure(nil) }
        try check(cancellation);return output
    }
}
