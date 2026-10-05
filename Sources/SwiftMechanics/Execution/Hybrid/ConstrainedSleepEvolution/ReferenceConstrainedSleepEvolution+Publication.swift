@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension ReferenceConstrainedSleepEvolution {
    @inline(never)
    internal func publish(_ publication:ConstrainedSleepPublication,session:any RuntimeSessionOperating,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> RuntimeAcceptedState {
        try check(cancellation)
        guard session.snapshot().checkpoint == publication.source else { throw .hybrid(.concurrentMutation) }
        do throws(RuntimeFailure) {
            let outcome=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
                guard !cancellation.isCancelled,!Task.isCancelled,session.snapshot().checkpoint == publication.source else { throw RuntimeFailure(.invalidOwnerAccess,message:"Whole constrained source/RNG/history changed before publication.") }
                try control.beginWorkBlock(units:1)
                guard trial.timeSeconds.bitPattern == publication.source.physical.time.bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Constrained source time changed.") }
                for record in publication.source.contributors { guard try trial.contributor(record.id) == record else { throw RuntimeFailure(.invalidOwnerAccess,message:"Constrained full source records changed.") } }
                for i in publication.source.physical.q.indices { guard try trial.position(at:i).bitPattern == publication.source.physical.q[i].bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Constrained q source changed.") } }
                for i in publication.source.physical.v.indices { guard try trial.velocity(at:i).bitPattern == publication.source.physical.v[i].bitPattern,try trial.acceleration(at:i).bitPattern == publication.source.physical.acceleration[i].bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Constrained v/a source changed.") } }
                for i in publication.physical.q.indices { try control.beginWorkBlock(units:1);try trial.setPosition(publication.physical.q[i],at:i) }
                for i in publication.physical.v.indices { try control.beginWorkBlock(units:1);try trial.setVelocity(publication.physical.v[i],at:i);try trial.setAcceleration(publication.physical.acceleration[i],at:i) }
                try trial.setTime(publication.physical.time)
                for record in publication.records { try control.beginWorkBlock(units:1);try trial.replaceContributor(record) }
                guard !cancellation.isCancelled,!Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Constrained publication cancelled after writes.") }
                return .accept
            }
            guard outcome.decision == .accept,outcome.accepted.checkpoint.acceptedSteps == publication.source.acceptedSteps+1,outcome.accepted.checkpoint.random == publication.source.random else { throw RuntimeFailure(.invalidOwnerAccess,message:"Constrained actual publication counter/RNG differs.") }
            return outcome.accepted
        } catch { throw .runtime(error) }
    }
}
