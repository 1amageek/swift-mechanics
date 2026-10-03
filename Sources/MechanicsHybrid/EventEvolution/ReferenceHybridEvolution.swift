import MechanicsJoints
import MechanicsCompiler
import MechanicsRuntime
import MechanicsIntegration
import MechanicsDynamics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceHybridEvolution: HybridEvolving {
    private let trajectory: any HybridTrajectoryQuerying
    private let environment: any HybridEventEnvironment
    private let continuation: HybridContinuationProvider
    private let adapter: any ImpactPortAdapting
    private let impulses: any NormalImpulseSolving
    private let admission: DynamicsAdmission
    private let massPolicy: DynamicsSolvePolicy
    public init(trajectory: any HybridTrajectoryQuerying, environment: any HybridEventEnvironment,
                continuation: HybridContinuationProvider, admission: DynamicsAdmission, massPolicy: DynamicsSolvePolicy,
                adapter: any ImpactPortAdapting = RigidHardImpactAdapter(), impulses: any NormalImpulseSolving = IndependentNormalImpulseSolver()) throws(HybridError) {
        guard trajectory.model.stamp == environment.catalog.model, continuation.catalog == environment.catalog,
              trajectory.continuation.descriptor == trajectory.equations.descriptor else { throw .staleModel }
        self.trajectory=trajectory; self.environment=environment; self.continuation=continuation
        self.adapter=adapter; self.impulses=impulses
        self.admission=admission; self.massPolicy=massPolicy
    }
    @inline(never)
    public func advance(_ session: any RuntimeSessionOperating, to time: Double, work initial: HybridEvolutionWork,
                        cancellation: HybridCancellation) throws(HybridEvolutionFailure) -> HybridEvolutionResult {
        var work=initial
        do throws(HybridError) {
            try cancellation.check()
            try validateStart(session,to:time)
            return completedResult(try runSegments(session,to:time,work:&work,cancellation:cancellation))
        } catch { throw contextualFailure(error,session:session,work:&work) }
    }
    @inline(never)
    private func validateStart(_ session: any RuntimeSessionOperating, to time: Double) throws(HybridError) {
        guard time.isFinite, time >= session.snapshot().checkpoint.physical.time else { throw .invalidInput }
    }
    @inline(never)
    private func completedResult(_ outcome: HybridRunOutcome) -> HybridEvolutionResult {
        HybridEvolutionResult(accepted:outcome.accepted,impacts:outcome.impacts,work:outcome.work)
    }
    @inline(never)
    private func contextualFailure(_ error: HybridError, session: any RuntimeSessionOperating,
                                   work: inout HybridEvolutionWork) -> HybridEvolutionFailure {
        work.failed(error)
        if case .trajectory(let failure)=error { do { try work.absorb(failure.work) } catch { work.failed(error) } }
        return HybridEvolutionFailure(cause:error,accepted:session.snapshot(),work:work)
    }
    @inline(never)
    private func runSegments(_ session: any RuntimeSessionOperating, to time: Double, work: inout HybridEvolutionWork,
                             cancellation: HybridCancellation) throws(HybridError) -> HybridRunOutcome {
        var results: [NormalImpulseResult]=[]
        results.reserveCapacity(continuation.policy.maximumEvents)
        while true {
            let step=try oneSegment(session,to:time,impacts:results.count,work:&work,cancellation:cancellation)
            if let impulse=step.impulse { results.append(impulse) }
            if step.accepted.checkpoint.physical.time == time { return HybridRunOutcome(accepted:step.accepted,impacts:results,work:work) }
        }
    }
    @inline(never)
    private func segmentContext(_ session: any RuntimeSessionOperating) throws(HybridError) -> HybridStepContext {
        let source=session.snapshot().checkpoint
        guard source.model == trajectory.model.stamp else { throw .staleModel }
        return HybridStepContext(source:source,history:try eventHistory(source))
    }
    @inline(never)
    private func oneSegment(_ session: any RuntimeSessionOperating, to time: Double, impacts: Int, work: inout HybridEvolutionWork,
                            cancellation: HybridCancellation) throws(HybridError) -> HybridStepResult {
        let context=try segmentContext(session)
        if context.source.physical.time == time { return HybridStepResult(accepted:session.snapshot(),impulse:nil) }
        try cancellation.check()
        let segment=try computeSegment(context:context,to:time,work:&work,cancellation:cancellation)
        if segment.impulse != nil, impacts >= continuation.policy.maximumEvents { throw .capacityExceeded }
        return try commitSegment(segment,context:context,session:session,work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func commitSegment(_ segment: HybridSegment, context: HybridStepContext, session: any RuntimeSessionOperating,
                               work: inout HybridEvolutionWork, cancellation: HybridCancellation) throws(HybridError) -> HybridStepResult {
        let accepted=try publish(segment,source:context.source,history:context.history,session:session,cancellation:cancellation)
        work.committed(impact:segment.impulse != nil)
        return HybridStepResult(accepted:accepted,impulse:segment.impulse)
    }
    private func eventHistory(_ source: RuntimeCheckpoint) throws(HybridError) -> HybridHistory {
        guard let record=source.contributors.first(where: { $0.id == continuation.schema.id }),
              let smooth=source.contributors.first(where: { $0.id == trajectory.continuation.schema.id }) else { throw .invalidContinuation }
        do {
            _=try trajectory.continuation.associatedHistory(smooth,physical:source.physical,equations:trajectory.equations)
            return try continuation.associatedHistory(record,physical:source.physical)
        } catch { throw .runtime(error) }
    }
    @inline(never)
    private func computeSegment(context: HybridStepContext, to time: Double,
                                work: inout HybridEvolutionWork, cancellation: HybridCancellation) throws(HybridError) -> HybridSegment {
        if let selected=try selectEvent(context:context,to:time,work:&work,cancellation:cancellation) {
            return try impactSegment(selected,work:&work,cancellation:cancellation)
        }
        return HybridSegment(checkpoint:try query(context,to:time,work:&work,cancellation:cancellation).checkpoint,impulse:nil)
    }
    @inline(never)
    private func selectEvent(context: HybridStepContext, to time: Double,
                             work: inout HybridEvolutionWork, cancellation: HybridCancellation) throws(HybridError) -> SelectedHybridEvents? {
        try selectCommonTime(collectRoots(context:context,to:time,work:&work,cancellation:cancellation),
            context:context,work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func collectRoots(context: HybridStepContext, to time: Double, work: inout HybridEvolutionWork,
                              cancellation: HybridCancellation) throws(HybridError) -> [LocatedHybridEvent] {
        let brackets=try environment.brackets(from:context.source,to:time,cancellation:cancellation)
        guard brackets.count <= continuation.policy.maximumCatalogEvents else { throw .capacityExceeded }
        var located: [LocatedHybridEvent]=[]; located.reserveCapacity(brackets.count)
        var seen=Set<UInt64>()
        for bracket in brackets {
            guard environment.catalog.eventIDs.contains(bracket.eventID), seen.insert(bracket.eventID).inserted,
                  bracket.lowerTime >= context.source.physical.time, bracket.upperTime <= time else { throw .invalidInput }
            if let root=try locate(bracket,context:context,work:&work,cancellation:cancellation) { located.append(root) }
        }
        located.sort { lhs,rhs in lhs.checkpoint.physical.time == rhs.checkpoint.physical.time ? lhs.eventID < rhs.eventID : lhs.checkpoint.physical.time < rhs.checkpoint.physical.time }
        return located
    }
    @inline(never)
    private func selectCommonTime(_ located: [LocatedHybridEvent], context: HybridStepContext,
                                  work: inout HybridEvolutionWork, cancellation: HybridCancellation) throws(HybridError) -> SelectedHybridEvents? {
        guard let first=located.first else {
            return nil
        }
        let impactTime=first.checkpoint.physical.time
        if let last=context.history.lastImpactTime, impactTime-last < continuation.policy.minimumEventSpacing { throw .chatter }
        guard impactTime > context.source.physical.time else { throw .chatter }
        var ids: [UInt64]=[]
        for root in located where abs(root.checkpoint.physical.time-impactTime) <= continuation.policy.timeTolerance {
            // One common-time sample must satisfy every simultaneous contact; grouping is not a pose overwrite.
            let sample=try environment.sample(eventID:root.eventID,state:first.checkpoint,work:&work.collision,cancellation:cancellation)
            guard abs(sample.gap) <= continuation.impactPolicy.lengthTolerance,
                  sample.separatingSpeed < -continuation.impactPolicy.speedTolerance else { throw .noDirectedBracket }
            ids.append(root.eventID)
        }
        ids.sort()
        return SelectedHybridEvents(checkpoint:first.checkpoint,eventIDs:ids)
    }
    @inline(never)
    private func impactSegment(_ selected: SelectedHybridEvents, work: inout HybridEvolutionWork,
                               cancellation: HybridCancellation) throws(HybridError) -> HybridSegment {
        let input=try environment.impactInput(state:selected.checkpoint,eventIDs:selected.eventIDs,work:&work.collision,cancellation:cancellation)
        guard input.model.stamp == trajectory.model.stamp, input.physical.state == selected.checkpoint.physical,
              input.expectedCollisionRevision == environment.catalog.geometryRevision,
              input.contacts.map({ $0.eventID }).sorted() == selected.eventIDs else { throw .staleModel }
        let prepared=try adapter.prepare(input,policy:continuation.impactPolicy,admission:admission,loadWork:&work.loads,work:&work.numerical,cancellation:cancellation)
        let jump=try impulses.solve(prepared,policy:continuation.impactPolicy,massPolicy:massPolicy,work:&work.numerical,contactWork:&work.contact,cancellation:cancellation)
        let physical=try environment.postJump(physical:selected.checkpoint.physical,velocity:jump.velocity)
        guard physical.time == selected.checkpoint.physical.time, physical.q == selected.checkpoint.physical.q,
              physical.v == jump.velocity, physical.revision == selected.checkpoint.physical.revision,
              physical.prescribedAnchors == selected.checkpoint.physical.prescribedAnchors else { throw .invalidInput }
        let smooth: RuntimeContributorState
        do { smooth=try trajectory.continuation.initialRecord(physical:physical,equations:trajectory.equations) }
        catch { throw .runtime(error) }
        var records=selected.checkpoint.contributors
        guard let index=records.firstIndex(where: { $0.id == smooth.id }) else { throw .invalidContinuation }; records[index]=smooth
        let checkpoint: RuntimeCheckpoint
        do { checkpoint=try RuntimeCheckpoint(model:selected.checkpoint.model,continuation:selected.checkpoint.continuation,
            physical:physical,contributors:records,random:selected.checkpoint.random,acceptedSteps:selected.checkpoint.acceptedSteps) } catch { throw .runtime(error) }
        return HybridSegment(checkpoint:checkpoint,impulse:jump)
    }
    @inline(never)
    private func locate(_ bracket: HybridEventBracket, context: HybridStepContext, work: inout HybridEvolutionWork,
                        cancellation: HybridCancellation) throws(HybridError) -> LocatedHybridEvent? {
        guard try hasDirectedBracket(readEndpoints(bracket,context:context,work:&work,cancellation:cancellation),
            eventID:bracket.eventID,work:&work,cancellation:cancellation) else { return nil }
        return try refineRoot(bracket,context:context,work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func readEndpoints(_ bracket: HybridEventBracket, context: HybridStepContext, work: inout HybridEvolutionWork,
                               cancellation: HybridCancellation) throws(HybridError) -> HybridBracketEndpoints {
        let low=try query(context,to:bracket.lowerTime,work:&work,cancellation:cancellation)
        let high=try query(context,to:bracket.upperTime,work:&work,cancellation:cancellation)
        return HybridBracketEndpoints(low:low,high:high)
    }
    @inline(never)
    private func hasDirectedBracket(_ endpoints: HybridBracketEndpoints, eventID: UInt64, work: inout HybridEvolutionWork,
                                    cancellation: HybridCancellation) throws(HybridError) -> Bool {
        let lowSample=try environment.sample(eventID:eventID,state:endpoints.low.checkpoint,work:&work.collision,cancellation:cancellation)
        let highSample=try environment.sample(eventID:eventID,state:endpoints.high.checkpoint,work:&work.collision,cancellation:cancellation)
        guard lowSample.gap > 0 else { throw .noDirectedBracket }
        if highSample.gap > 0 { return false }
        guard highSample.separatingSpeed < -continuation.impactPolicy.speedTolerance else { throw .grazing }
        return true
    }
    @inline(never)
    private func refineRoot(_ bracket: HybridEventBracket, context: HybridStepContext, work: inout HybridEvolutionWork,
                            cancellation: HybridCancellation) throws(HybridError) -> LocatedHybridEvent {
        var lower=bracket.lowerTime, upper=bracket.upperTime
        for _ in 0..<continuation.policy.maximumRootIterations {
            try cancellation.check(); try work.iterated()
            let mid=lower+(upper-lower)*0.5
            guard mid > lower, mid < upper else { throw .noDirectedBracket }
            let candidate=try query(context,to:mid,work:&work,cancellation:cancellation)
            let sample=try environment.sample(eventID:bracket.eventID,state:candidate.checkpoint,work:&work.collision,cancellation:cancellation)
            if upper-lower <= continuation.policy.timeTolerance, abs(sample.gap) <= continuation.impactPolicy.lengthTolerance,
               sample.separatingSpeed < -continuation.impactPolicy.speedTolerance {
                return LocatedHybridEvent(eventID:bracket.eventID,checkpoint:candidate.checkpoint,bracketLower:lower,bracketUpper:upper)
            }
            if sample.gap > 0 { lower=mid } else { upper=mid }
        }
        throw .noDirectedBracket
    }
    @inline(never)
    private func query(_ context: HybridStepContext, to time: Double, work: inout HybridEvolutionWork,
                       cancellation: HybridCancellation) throws(HybridError) -> HybridCheckpointOwner {
        try cancellation.check()
        if time == context.source.physical.time { return HybridCheckpointOwner(context.source) }
        return try certifyQuery(chargedQuery(context,to:time,work:&work,cancellation:cancellation),context:context,to:time)
    }
    @inline(never)
    private func chargedQuery(_ context: HybridStepContext, to time: Double, work: inout HybridEvolutionWork,
                              cancellation: HybridCancellation) throws(HybridError) -> HybridCheckpointOwner {
        try work.beginQuery(policy:continuation.policy)
        let result=try trajectory.query(from:context.source,to:time,cancellation:cancellation)
        try work.absorb(result.work)
        return HybridCheckpointOwner(result.checkpoint)
    }
    @inline(never)
    private func certifyQuery(_ result: HybridCheckpointOwner, context: HybridStepContext, to time: Double) throws(HybridError) -> HybridCheckpointOwner {
        let candidate=result.checkpoint
        let source=context.source
        guard candidate.model == source.model, candidate.continuation == source.continuation,
              candidate.physical.time == time, candidate.random == source.random,
              candidate.contributors.count == source.contributors.count else { throw .invalidContinuation }
        for record in source.contributors where record.id != trajectory.continuation.schema.id {
            guard candidate.contributors.first(where: { $0.id == record.id }) == record else { throw .invalidContinuation }
        }
        return result
    }
    @inline(never)
    private func publish(_ segment: HybridSegment, source: RuntimeCheckpoint, history: HybridHistory,
                         session: any RuntimeSessionOperating, cancellation: HybridCancellation) throws(HybridError) -> RuntimeAcceptedState {
        let physical=segment.checkpoint.physical
        let events: RuntimeContributorState
        do { events=try continuation.record(physical:physical,previous:history,eventIDs:segment.impulse?.eventIDs ?? []) } catch { throw .runtime(error) }
        guard let smooth=segment.checkpoint.contributors.first(where: { $0.id == trajectory.continuation.schema.id }),
              let oldSmooth=source.contributors.first(where: { $0.id == smooth.id }),
              let oldEvents=source.contributors.first(where: { $0.id == events.id }) else { throw .invalidContinuation }
        do { _=try trajectory.continuation.associatedHistory(smooth,physical:physical,equations:trajectory.equations) } catch { throw .runtime(error) }
        do throws(RuntimeFailure) {
            let outcome=try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
                guard !cancellation.isCancelled, !Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Hybrid publication cancelled.") }
                try control.beginWorkBlock(units:1)
                guard trial.timeSeconds == source.physical.time, try trial.contributor(oldSmooth.id) == oldSmooth,
                      try trial.contributor(oldEvents.id) == oldEvents else { throw RuntimeFailure(.invalidOwnerAccess,message:"Hybrid chart/event prefix changed during isolated search.") }
                for i in source.physical.q.indices { guard try trial.position(at:i) == source.physical.q[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Hybrid q prefix changed.") } }
                for i in source.physical.v.indices { guard try trial.velocity(at:i) == source.physical.v[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Hybrid v prefix changed.") } }
                for i in physical.q.indices { try control.beginWorkBlock(units:1); try trial.setPosition(physical.q[i],at:i) }
                for i in physical.v.indices { try control.beginWorkBlock(units:1); try trial.setVelocity(physical.v[i],at:i); try trial.setAcceleration(physical.acceleration[i],at:i) }
                try trial.setTime(physical.time); try trial.replaceContributor(smooth); try trial.replaceContributor(events)
                guard !cancellation.isCancelled else { throw RuntimeFailure(.cancelled,message:"Hybrid publication cancelled after writes.") }
                return .accept
            }
            guard outcome.decision == .accept else { throw RuntimeFailure(.invalidOwnerAccess,message:"Runtime rejected requested hybrid acceptance.") }
            return outcome.accepted
        } catch { throw .runtime(error) }
    }
}
