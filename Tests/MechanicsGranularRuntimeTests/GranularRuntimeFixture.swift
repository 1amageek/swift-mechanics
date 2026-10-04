import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct GranularRuntimeFixture: Sendable {
    typealias Handler=GranularRuntimeCheckpointHandler<ReferenceModelRevisionUpdater>
    let model: CompiledMechanicalModel
    let source: GranularRuntimeSource
    let journal: GranularRuntimeJournal
    let session: RuntimeSession<Handler>
    let operation: ReferenceGranularTrialOperator
    init(mass: Double = 1,seed: UInt64 = 123,steps: Int = 16,stepWork: Int = 4,numericalOperations: Int = 500000,
         policy: GranularPolicy? = nil,evolution: any GranularEvolving = ReferenceGranularEvolution()) throws {
        let model=try GranularRuntimeCarrierFixtures.model()
        let policy=try policy ?? GranularRuntimeParticleFixtures.policy()
        let initial=try GranularRuntimeParticleFixtures.prepare(motions:[GranularMotion(position:Vector3(0,0,0.49))],plane:true,
            planeVelocity:.unitX,friction:true,random:RuntimeRandomState(seed:seed),particleMass:mass)
        let physics=try Self.budget(operations:numericalOperations)
        var work=try Self.work(physics)
        let source=try GranularRuntimeSource(initial:initial,carrier:model.stamp,policy:policy,timeStepSeconds:0.001,
            gravityChoices:[Vector3(0,0,-9),Vector3(0,0,-10)],maximumAcceptedSteps:steps,contributorID:"granular-journal",
            maximumBytes:16384,maximumMetadataBytes:8192,physicsBudget:physics,work:&work)
        let journal=GranularRuntimeJournal(source:source),record=try journal.encode(journal.initial(work:&work),work:&work)
        let capacity=try RuntimeCapacity(maximumPhysicalScalars:0,maximumContributors:1,maximumContributorBytes:16384,
            maximumMetadataBytes:16384,maximumCheckpointBytes:32768,maximumValidationWork:1000000,
            maximumValidationScratchBytes:400000,maximumObservationLeases:1,maximumBatchStates:1,maximumTransactions:100,
            maximumStepWorkUnits:stepWork,maximumWorkBetweenSafePoints:1)
        let configuration=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"granular-journal-v1",backend:"original-reference-cpu",precision:"float64"),
            requiredContributors:[journal.schema],capacity:capacity,determinism:.sameBuildReplay,workload:"granular-runtime-physics")
        self.model=model;self.source=source;self.journal=journal
        operation=ReferenceGranularTrialOperator(journal:journal,evolution:evolution)
        session=try RuntimeSession(model:model,configuration:configuration,initialState:model.descriptor.initialState,
            contributors:[record],seed:seed,checkpoints:Handler(journal:journal,revisions:ReferenceModelRevisionUpdater()))
    }
    static func budget(operations: Int = 500000) throws -> GranularRuntimePhysicsBudget {
        try GranularRuntimePhysicsBudget(numerical:NumericalBudget(scalarStorage:10000,arithmeticOperations:operations,iterations:10000),
            collision:CollisionBudget(scalarStorage:10000,operations:100000,iterations:10000,records:100),
            contact:ContactBudget(operations:100000,scalarStorage:10000,records:100),maximumSupplierCalls:10000)
    }
    static func work(_ physics: GranularRuntimePhysicsBudget,bytes: Int = 400000,units: Int = 1000000,
                     cancel: @escaping @Sendable () -> Bool = { false }) throws -> GranularRuntimeWork {
        try GranularRuntimeWork(physics:physics,maximumBytes:bytes,maximumWorkUnits:units,isCancelled:cancel)
    }
    func advance(decision: RuntimeTrialDecision = .accept,duration: Double = 0.001) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let model=self.model,operation=self.operation,physics=source.physicsBudget
        return try session.performTrial { (trial: inout RuntimeTrial,control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work: GranularRuntimeWork
            do { work=try Self.work(physics) } catch { throw RuntimeFailure(.invalidInput,message:"Fixture work construction failed.") }
            _=try operation.advance(model:model,duration:duration,trial:&trial,control:&control,work:&work)
            return decision
        }
    }
    func accepted() throws -> GranularRuntimeContinuation {
        var work=try Self.work(source.physicsBudget)
        return try journal.decode(session.snapshot().checkpoint.contributors[0],work:&work)
    }
    static func changed(_ record: RuntimeContributorState,offset: Int,value: UInt64) throws -> RuntimeContributorState {
        var bytes=record.bytes;for i in 0..<8 { bytes[offset+i]=UInt8(truncatingIfNeeded:value >> (8*i)) }
        return try RuntimeContributorState(id:record.id,category:record.category,version:record.version,bytes:bytes)
    }
}
