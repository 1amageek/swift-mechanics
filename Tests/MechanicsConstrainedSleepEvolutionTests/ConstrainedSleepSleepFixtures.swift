import SwiftMechanics
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal enum ConstrainedSleepSleepFixtures {
    static func work(token:HybridCancellation = HybridCancellation(),operations:Int=100000000,storage:Int=1000000,loads:Int=1000000) throws -> IslandSleepWork {
        IslandSleepWork(physical:StationaryIslandWork(numerical:NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:100000)),loads:LoadWork(budget:try LoadBudget(maximumWork:loads,maximumScalars:100000,isCancelled:{token.isCancelled}))),contributorEncoding:NumericalWork(budget:try NumericalBudget(scalarStorage:1000000,arithmeticOperations:100000000,iterations:100000)))
    }
    static func owner(drive:[Double]=[0,0,0],dwell:Double=0.1,dynamics:any StationaryIslandComputing=ReferenceStationaryIslandDynamics(),model:CompiledMechanicalModel?=nil,token:HybridCancellation=HybridCancellation(),participant:(any IslandEndpointContributing)?=nil,calls:Int=100000,method:ExplicitIntegrationMethod = .classicalRK4,errorScale:Double=1e-8) throws -> IslandCheckpointedMechanismSleep {
        let source=try model ?? ConstrainedSleepMechanicalFixtures.model(time:0)
        let program=try ConstrainedSleepMechanicalFixtures.program(drive:drive,model:source,policy:ConstrainedSleepMechanicalFixtures.policy(token:token))
        let budget=try IntegrationBudget(maximumCoordinates:6,maximumAttempts:100,maximumAcceptedSteps:100,maximumOuterArithmetic:1000000,supplier:NumericalBudget(scalarStorage:1000000,arithmeticOperations:100000000,iterations:100000))
        let dimensions=program.constraints.layout.dimensions+program.constraints.layout.dimensions.map { PhysicalDimension(length:$0.length,time:-1,angle:$0.angle) }
        let integration=try ExplicitIntegrationPolicy(method:method,initialStep:0.1,minimumStep:1e-10,maximumStep:0.1,safety:0.8,minimumFactor:0.2,maximumFactor:2,scales:dimensions.map { try ODEErrorScale(dimension:$0,absoluteSI:errorScale,relative:1e-8) },maximumContinuationBytes:1000000,budget:budget)
        return try IslandCheckpointedMechanismSleep(identity:"constrained-event-ode",program:program,dynamics:dynamics,policy:MechanismSleepContinuationPolicy(thresholds:ConstrainedSleepMechanicalFixtures.thresholds(),minimumRestDuration:dwell,maximumIdentityBytes:500000),integration:integration,operationPolicy:IslandSleepOperationPolicy(maximumSupplierInvocations:calls,maximumQueries:512,maximumQuerySteps:100,maximumRecordBytes:1000000),participant:participant)
    }
    static func configuration(_ owner:IslandCheckpointedMechanismSleep) throws -> RuntimeConfiguration {
        try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"mixed-test-v1",backend:"reference",precision:"float64"),requiredContributors:owner.schemas,
            capacity:RuntimeCapacity(maximumPhysicalScalars:20,maximumContributors:4,maximumContributorBytes:1000000,maximumMetadataBytes:1000000,maximumCheckpointBytes:3000000,maximumValidationWork:100000000,maximumValidationScratchBytes:10000000,maximumObservationLeases:2,maximumBatchStates:10,maximumTransactions:1000,maximumStepWorkUnits:1000000,maximumWorkBetweenSafePoints:100),determinism:.sameBuildReplay,workload:"mixed-sleep")
    }
    static func physical(_ owner:IslandCheckpointedMechanismSleep,q:[Double]=[0,0,0.75],v:[Double]=[0,0,-1],time:Double=0) throws -> KinematicState {
        let raw=try KinematicState(revision:1,time:time,q:q,v:v,acceleration:[0,0,0]);var a=[Double](repeating:0,count:3),work=try ConstrainedSleepMechanicalFixtures.work()
        for island in owner.program.islands {
            let motion=try ReferenceStationaryIslandDynamics().motion(program:owner.program,islandID:island.id,physical:raw,work:&work)
            for k in island.sourceCoordinateIndices.indices { a[island.sourceCoordinateIndices[k]]=motion.acceleration[k] }
        }
        return try KinematicState(revision:1,time:time,q:q,v:v,acceleration:a)
    }
    static func session(_ owner:IslandCheckpointedMechanismSleep,physical:KinematicState?=nil) throws -> RuntimeSession<IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>> {
        let p=try physical ?? self.physical(owner)
        var records=[try owner.initialRecord(physical:p),try owner.initialIntegrationRecord(physical:p)]
        if let participant=owner.participant { var work=try ConstrainedSleepMechanicalFixtures.numerical();let checkpoint=try RuntimeCheckpoint(model:owner.model.stamp,continuation:configuration(owner).continuation,physical:p,contributors:records,random:RuntimeRandomState(seed:99),acceptedSteps:0);records.append(try participant.recordEndpoint(source:checkpoint,physical:p,acceptedSequence:0,work:&work)) }
        return try RuntimeSession(model:owner.model,configuration:configuration(owner),initialState:p,contributors:records,seed:99,checkpoints:IslandSleepCheckpointHandler(sleep:owner,revisions:ReferenceModelRevisionUpdater()))
    }
    static func history(_ owner:IslandCheckpointedMechanismSleep,_ session:any RuntimeSessionOperating) throws -> IslandSleepHistory {
        guard let record=session.snapshot().checkpoint.contributors.first(where:{$0.id == owner.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Sleep test record missing.") };return try owner.history(record)
    }
}
