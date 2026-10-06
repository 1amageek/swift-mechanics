import SwiftMechanics
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct ConstrainedSleepFixtures {
    let sleep:IslandCheckpointedMechanismSleep
    let environment:GearedStrikerEventEnvironment
    let events:ConstrainedSleepEventContinuation
    let session:RuntimeSession<IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>>
    let service:ReferenceConstrainedSleepEvolution
    let token:HybridCancellation
    init(restitution:Double=1,q:Double=0.75,time:Double=0,maximumEvents:Int=4,queries:Int=128,iterations:Int=64,
         geometryOffset:Double=1,preparing:any ConstrainedImpactPreparing=ReferenceConstrainedImpactPreparer(),impulses:any ConstrainedNormalImpulseSolving=ReferenceConstrainedNormalImpulseSolver(),
         collisionQueries:any CollisionGeometryQuerying=AnalyticCollisionQueries(),sessionWrapping:Bool=false) throws {
        let token=HybridCancellation(),base=try ConstrainedSleepSleepFixtures.owner(token:token)
        let physical=try ConstrainedSleepSleepFixtures.physical(base,q:[0,0,q],time:time)
        let contact=try ConstrainedSleepImpactFixtures.input(base,physical:ConstrainedSleepSleepFixtures.physical(base,q:[0,0,0.5],time:time),restitution:restitution)
        let binding=contact.contacts[0],policy=try ConstrainedSleepImpactFixtures.policy(),ep=try HybridEvolutionPolicy(maximumEvents:maximumEvents,maximumQueries:queries,maximumRootIterations:iterations,maximumCatalogEvents:1,maximumContinuationBytes:100000,timeTolerance:1e-10,minimumEventSpacing:1e-6)
        let first=contact.collision.proxies[0],second=contact.collision.proxies[1]
        let mount=RigidTransform(rotation:.identity,translation:try Vector3(geometryOffset,0,0))
        let environment=try GearedStrikerEventEnvironment(program:base.program,first:first,second:second,firstColliderToBody:mount,secondColliderToBody:binding.secondColliderToBody,law:binding.law,eventID:41,geometryRevision:1,queryPolicy:CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0),evolutionPolicy:ep,impactPolicy:policy,queries:collisionQueries)
        let events=try ConstrainedSleepEventContinuation(environment:environment,policy:ep)
        let sleep=try ConstrainedSleepSleepFixtures.owner(token:token,participant:events)
        let session=try ConstrainedSleepSleepFixtures.session(sleep,physical:physical),handler=IslandSleepCheckpointHandler(sleep:sleep,revisions:ReferenceModelRevisionUpdater())
        service=try ReferenceConstrainedSleepEvolution(sleep:sleep,environment:environment,continuation:events,configuration:session.configuration,checkpoints:handler,preparing:preparing,impulses:impulses)
        self.sleep=sleep;self.environment=environment;self.events=events;self.session=session;self.token=token
    }
    func work(collisionOperations:Int=10000000,operations:Int=100000000,contactOperations:Int=100000) throws -> ConstrainedSleepEvolutionWork {
        ConstrainedSleepEvolutionWork(numerical:NumericalWork(budget:try NumericalBudget(scalarStorage:1000000,arithmeticOperations:operations,iterations:100000)),collision:CollisionWork(budget:try CollisionBudget(scalarStorage:1000000,operations:collisionOperations,iterations:100000,records:100)),contact:ContactWork(budget:try ContactBudget(operations:contactOperations,scalarStorage:100000,records:10)),loads:LoadWork(budget:try LoadBudget(maximumWork:1000000,maximumScalars:100000,isCancelled:{token.isCancelled})),islands:try ConstrainedSleepSleepFixtures.work(token:token))
    }
    func enterSleep() throws { var work=try ConstrainedSleepSleepFixtures.work(token:token);_=try sleep.step(session,work:&work) }
    func eventHistory(_ accepted:RuntimeAcceptedState) throws -> ConstrainedSleepEventHistory {
        guard let record=accepted.checkpoint.contributors.first(where:{$0.id == events.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Test event history missing.") };return try events.history(record)
    }
}
