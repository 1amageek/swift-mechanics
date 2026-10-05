@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension IslandCheckpointedMechanismSleep {
    @inline(never)
    public func prepareImpactWake(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,impact:ConstrainedNormalImpulseResult,work:inout IslandSleepWork) throws(IslandSleepFailure) -> PreparedIslandImpactWake {
        let execution=IslandSleepExecution(work:work,maximum:operationPolicy.maximumSupplierInvocations)
        defer { work=execution.read() }
        do throws(RuntimeFailure) {
            _=try stepAdapter(source:source,execution:execution);try validateImpact(source:source,endpoint:endpoint,impact:impact)
            return try wakePhysical(source:source,endpoint:endpoint,impact:impact,execution:execution)
        } catch { throw IslandSleepFailure(execution.failure() ?? .runtime(error),accepted:source,work:execution.read()) }
    }
    @inline(never)
    private func validateImpact(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,impact:ConstrainedNormalImpulseResult) throws(RuntimeFailure) {
        let original=program.constraints,actual=impact.source.constraints,input=impact.source.source
        guard endpoint.owner === self,endpoint.source == source.checkpoint,source.checkpoint.acceptedSteps < UInt64.max,
              sameModel(input.model),samePhysical(input.physical.state,endpoint.physical),input.physical.stamp == model.stamp,
              impact.velocity.count == endpoint.physical.v.count,impact.velocity.allSatisfy({$0.isFinite}),impact.eventID > 0,
              impact.source.retainedRowIDs == original.rows.map({$0.id}),actual.rows.count == original.rows.count,
              actual.layout.coordinateIDs == original.layout.coordinateIDs,actual.layout.dimensions == original.layout.dimensions,
              IslandSleepBits.equal(actual.layout.scales,original.layout.scales),actual.layout.timeScale.bitPattern == original.layout.timeScale.bitPattern,actual.layout.revision == original.layout.revision,
              IslandSleepBits.equal(actual.minimumPosition,original.minimumPosition),IslandSleepBits.equal(actual.maximumPosition,original.maximumPosition),actual.minimumTime.bitPattern == original.minimumTime.bitPattern,actual.maximumTime.bitPattern == original.maximumTime.bitPattern else { throw RuntimeFailure(.invalidContributor,message:"Constrained wake result/source/retained law differs.") }
        for i in original.rows.indices {
            let x=actual.rows[i],y=original.rows[i]
            guard x.id == y.id,x.constant.bitPattern == y.constant.bitPattern,IslandSleepBits.equal(x.linear,y.linear),IslandSleepBits.equal(x.hessian,y.hessian),x.timeLinear.bitPattern == y.timeLinear.bitPattern,x.timeQuadratic.bitPattern == y.timeQuadratic.bitPattern,IslandSleepBits.equal(x.mixedTime,y.mixedTime) else { throw RuntimeFailure(.invalidContributor,message:"Constrained wake original retained coefficients differ.") }
        }
    }
    @inline(never)
    private func wakePhysical(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,impact:ConstrainedNormalImpulseResult,execution:IslandSleepExecution) throws(RuntimeFailure) -> PreparedIslandImpactWake {
        let p=endpoint.physical
        var numerical=NumericalWork(budget:execution.read().physical.numerical.budget)
        try execution.reserveOwned(try IslandSleepBits.product(4,p.v.count),integration:&numerical)
        let new:KinematicState
        do throws(JointError) { new=try KinematicState(revision:p.revision,time:p.time,q:p.q,v:impact.velocity,acceleration:[Double](repeating:0,count:p.v.count)) }
        catch { throw RuntimeFailure(.invalidState,message:"Accepted impulse physical source construction failed.") }
        let flags=[Bool](repeating:false,count:program.islands.count),proofs=[StationaryIslandRestCertificate?](repeating:nil,count:flags.count)
        let a=try acceleration(physical:new,flags:flags,proofs:proofs,execution:execution,work:&numerical)
        let accepted:KinematicState
        do throws(JointError) { accepted=try KinematicState(revision:p.revision,time:p.time,q:p.q,v:impact.velocity,acceleration:a) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual post-impact acceleration construction failed.") }
        return try encodeWake(source:source,endpoint:endpoint,impact:impact,physical:accepted,execution:execution)
    }
    @inline(never)
    private func encodeWake(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,impact:ConstrainedNormalImpulseResult,physical:KinematicState,execution:IslandSleepExecution) throws(RuntimeFailure) -> PreparedIslandImpactWake {
        guard let record=endpoint.accepted.checkpoint.contributors.first(where:{$0.id == schema.id}),let integrationRecord=source.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Wake source histories missing.") }
        let old=try history(record),integrationHistory=try continuation.history(integrationRecord)
        try execution.reserveEncoding(try IslandSleepBits.sum(schema.maximumBytes,try IslandSleepBits.product(3,program.islands.count)))
        var affected=[Bool](repeating:false,count:program.islands.count)
        for j in program.islands.indices {
            affected[j]=program.islands[j].sourceCoordinateIndices.contains(where:{i in impact.source.impact.normalRows[i] != 0 || impact.retainedGeneralizedImpulse[i] != 0 || impact.velocity[i].bitPattern != endpoint.physical.v[i].bitPattern})
        }
        guard affected.contains(true) else { throw RuntimeFailure(.invalidContributor,message:"Physical constrained impact has no affected structural island.") }
        var since=old.restSince,flags=old.asleep
        for j in affected.indices where affected[j] { flags[j]=false;since[j]=physical.time }
        let h=IslandSleepHistory(time:physical.time,sequence:source.checkpoint.acceptedSteps+1,q:physical.q,v:physical.v,ids:old.islandIDs,asleep:flags,since:since,wakeSequence:source.checkpoint.acceptedSteps+1,wakeTime:physical.time,eventID:impact.eventID,kind:1,affected:affected)
        return try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
            do throws(NumericalError) { try work.requireStorage(schema.maximumBytes);try work.chargeOperations(schema.maximumBytes) }
            catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Wake encoding receipt exhausted.") }
            let sleep=try self.record(h),integration=try continuation.record(acceptedTime:physical.time,point:physical.q+physical.v,nextStep:integrationHistory.nextStep,acceptedSteps:source.checkpoint.acceptedSteps+1,normalizedError:continuation.policy.method == .classicalRK4 ? nil : 0)
            return PreparedIslandImpactWake(owner:self,source:source.checkpoint,physical:physical,sleep:sleep,integration:integration,affected:program.islands.indices.filter({affected[$0]}).map({program.islands[$0].id}),eventID:impact.eventID)
        }
    }
}
