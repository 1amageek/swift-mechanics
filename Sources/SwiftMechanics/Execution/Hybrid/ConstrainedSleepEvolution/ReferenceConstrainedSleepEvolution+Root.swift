@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ReferenceConstrainedSleepEvolution {
    @inline(never)
    internal func locate(_ source:ConstrainedSleepSource,through limit:Double,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> IslandSleepTrajectoryEndpoint? {
        try check(cancellation)
        let brackets=try ConstrainedSleepInvocation.collision(&work) { (receipt:inout CollisionWork) throws(HybridError) in try environment.brackets(from:source.accepted.checkpoint,through:limit,work:&receipt,cancellation:cancellation) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Only one catalog contact/closing bracket has original simultaneous-law authority here. Coupled multiple root groups must be refused until their producer is implemented.
        guard brackets.count <= 1 else { throw .hybrid(.unsupportedDomain) }
        guard let bracket=brackets.first else { return nil }
        guard environment.catalog.eventIDs == [bracket.eventID],bracket.lowerTime >= source.accepted.checkpoint.physical.time,bracket.upperTime <= limit else { throw .hybrid(.invalidInput) }
        let low=try query(source,to:bracket.lowerTime,work:&work,cancellation:cancellation),lowSample=try sample(low,work:&work,cancellation:cancellation)
        guard lowSample.gap > 0 else { throw .hybrid(.noDirectedBracket) }
        let high=try query(source,to:bracket.upperTime,work:&work,cancellation:cancellation),highSample=try sample(high,work:&work,cancellation:cancellation)
        if highSample.gap > 0 { return nil }
        guard highSample.separatingSpeed < -environment.impactPolicy.impact.speedTolerance,lowSample.separatingSpeed < -environment.impactPolicy.impact.speedTolerance else { throw .hybrid(.grazing) }
        return try refine(source,lower:bracket.lowerTime,upper:bracket.upperTime,work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func sample(_ endpoint:IslandSleepTrajectoryEndpoint,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> HybridEventSample {
        try ConstrainedSleepInvocation.collision(&work) { (receipt:inout CollisionWork) throws(HybridError) in try environment.sample(eventID:environment.catalog.eventIDs[0],endpoint:endpoint,work:&receipt,cancellation:cancellation) }
    }
    @inline(never)
    private func refine(_ source:ConstrainedSleepSource,lower initialLower:Double,upper initialUpper:Double,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> IslandSleepTrajectoryEndpoint {
        var lower=initialLower,upper=initialUpper
        for _ in 0..<continuation.policy.maximumRootIterations {
            try check(cancellation)
            guard work.rootIterations < continuation.policy.maximumRootIterations else { throw .hybrid(.capacityExceeded) }
            work.rootIterations+=1
            do throws(NumericalError) { try work.numerical.requireStorage(4);try work.numerical.chargeOperations(16);try work.numerical.advanceIteration() } catch { throw .hybrid(.numerical(error)) }
            let mid=lower+(upper-lower)*0.5
            guard mid.isFinite,mid>lower,mid<upper else { throw .hybrid(.noDirectedBracket) }
            let endpoint=try query(source,to:mid,work:&work,cancellation:cancellation),actual=try sample(endpoint,work:&work,cancellation:cancellation)
            if upper-lower <= continuation.policy.timeTolerance,abs(actual.gap) <= environment.impactPolicy.impact.lengthTolerance,actual.separatingSpeed < -environment.impactPolicy.impact.speedTolerance { return endpoint }
            if actual.gap>0 { lower=mid } else { upper=mid }
        }
        throw .hybrid(.noDirectedBracket)
    }
}
