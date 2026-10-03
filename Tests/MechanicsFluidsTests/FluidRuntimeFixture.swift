import MechanicsModel
import MechanicsCompiler
import MechanicsRuntime
import MechanicsNumerics
import MechanicsFluids
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct FluidRuntimeFixture {
    typealias Handler=ReferenceRuntimeCheckpointHandler<FluidRuntimeContributors,ReferenceModelRevisionUpdater>
    typealias Session=RuntimeSession<Handler>
    let model:CompiledMechanicalModel
    let channel:FluidChannel
    let codec:FixedFluidContinuationCodec
    let operation:ReferenceFluidTrialOperator
    let session:Session
    init(payloadTime:Double=0,maximumStepWork:Int=10000) throws {
        let model=try FluidFixtures.model(),channel=try FluidFixtures.channel(cells:8,model:model.stamp)
        let codec=try FixedFluidContinuationCodec(channel:channel,contributorID:"fluid-channel",maximumBytes:4096,pressureGradientTolerance:1e-8)
        let capacity=try RuntimeCapacity(maximumPhysicalScalars:0,maximumContributors:1,maximumContributorBytes:4096,
            maximumMetadataBytes:2048,maximumCheckpointBytes:8192,maximumValidationWork:10000,maximumValidationScratchBytes:10000,
            maximumObservationLeases:1,maximumBatchStates:1,maximumTransactions:1000,maximumStepWorkUnits:maximumStepWork,maximumWorkBetweenSafePoints:1)
        let config=try RuntimeConfiguration(continuation:RuntimeContinuationIdentity(build:"fluid-reference-v1",backend:"reference-cpu",precision:"float64"),
            requiredContributors:[codec.schema],capacity:capacity,determinism:.sameBuildReplay,workload:"viscous-channel")
        let handler=try Handler(contributors:FluidRuntimeContributors(codec:codec),revisions:ReferenceModelRevisionUpdater())
        let initial=try FluidFixtures.state(channel:channel,boundary:FluidFixtures.boundary(),time:payloadTime)
        var byteWork=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        let record=try codec.encode(initial,work:&byteWork)
        self.model=model;self.channel=channel;self.codec=codec
        self.operation=ReferenceFluidTrialOperator(codec:codec,evolution:FluidFixtures.solver())
        self.session=try Session(model:model,configuration:config,initialState:model.descriptor.initialState,contributors:[record],seed:1,checkpoints:handler)
    }
    func advance(boundary:FluidBoundary,duration:Double,decision:RuntimeTrialDecision) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let model=self.model,op=operation
        return try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            var numerical:NumericalWork; var bytes:FluidByteWork; let policy:FluidPolicy
            do { numerical=try FluidFixtures.work();bytes=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000);policy=try FluidFixtures.policy() }
            catch { throw RuntimeFailure(.invalidInput,message:"Fluid fixture budget creation failed.") }
            _=try op.advance(model:model,boundary:boundary,duration:duration,policy:policy,trial:&trial,control:&control,numerical:&numerical,bytes:&bytes)
            return decision
        }
    }
    func accepted() throws -> FluidState {
        let checkpoint=session.snapshot().checkpoint
        guard checkpoint.contributors.count == 1 else { throw RuntimeFailure(.missingContributor,message:"Fixture fluid contributor absent.") }
        var bytes=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000)
        return try codec.decode(checkpoint.contributors[0],work:&bytes)
    }
}
