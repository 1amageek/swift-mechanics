@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct ControlCheckpointHandler: RuntimeCheckpointHandling, Sendable {
    let provider:ControlContributorProvider
    let plant:PrismaticControlPlant
    let controller:SampledController
    let initialSequence:UInt64
    let policy:ControlPolicy
    @inline(never)
    func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        try cancellation?.check()
        guard !policy.isCancelled(),!Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Control admission cancelled.") }
        guard checkpoint.contributors.count == 3,checkpoint.physical.q.count == 1,checkpoint.physical.v.count == 1,checkpoint.physical.acceleration.count == 1 else { throw RuntimeFailure(.invalidContributor,message:"Control checkpoint shape differs.") }
        let cap=configuration.capacity
        var bytes=0
        for record in checkpoint.contributors {
            var count=0
            for _ in record.id.utf8 {
                guard !policy.isCancelled(),!Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Control metadata validation cancelled.") }
                guard count < policy.maximumMetadataBytes,bytes < cap.maximumValidationWork else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Control record identity exceeds metadata/work bounds.") }
                count += 1;bytes += 1
            }
        }
        for record in checkpoint.contributors {
            let next=bytes.addingReportingOverflow(record.bytes.count)
            guard !next.overflow,next.partialValue <= cap.maximumContributorBytes,next.partialValue <= cap.maximumValidationWork else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Control cross-association exceeds byte/work budget.") };bytes=next.partialValue
        }
        guard let c=checkpoint.contributors.first(where:{$0.id == provider.codec.schema.id}),
              let a=checkpoint.contributors.first(where:{$0.id == controller.servo.binding.actuator.key}),
              let i=checkpoint.contributors.first(where:{$0.id == provider.integration.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Control checkpoint is incomplete.") }
        let history=try provider.codec.history(c),integration=try provider.integration.history(i)
        var work=ActuationWork(budget:provider.actuator.controlBudget)
        let actuator:ActuatorState
        do { actuator=try provider.actuator.codec.decode(a,binding:controller.servo.binding,work:&work) }
        catch { throw RuntimeFailure(.invalidContributor,message:"Control actuator state incompatible.") }
        let time:Double
        do { time=try provider.codec.clock.time(at:history.tick) }
        catch { throw RuntimeFailure(.invalidContributor,message:"Controller clock invalid.") }
        let sequence=initialSequence.addingReportingOverflow(history.tick)
        guard !sequence.overflow,!history.pending,actuator.mode == controller.mode,actuator.sequence == sequence.partialValue,
              time == checkpoint.physical.time,time == actuator.time,time == integration.acceptedTime,time == history.intervalEnd,
              integration.acceptedPoint == [checkpoint.physical.q[0],checkpoint.physical.v[0]],
              history.endpointPosition == checkpoint.physical.q[0],history.endpointRate == checkpoint.physical.v[0],
              abs(history.endpointPosition) <= policy.maximumPositionMeters,abs(history.endpointRate) <= min(policy.maximumRateMetersPerSecond,controller.servo.speedLimit) else { throw RuntimeFailure(.invalidContributor,message:"Physical, controller, actuator and integration endpoint disagree.") }
        if history.issued {
            guard history.tick > 0 else { throw RuntimeFailure(.invalidContributor,message:"Issued control history has no sample.") }
            let start:Double
            do { start=try provider.codec.clock.time(at:history.tick-1) } catch { throw RuntimeFailure(.invalidContributor,message:"Sample clock invalid.") }
            guard history.sourceTime == start,history.sampleTickTime == start,
                  ControlArithmetic.agrees(history.actuatorIntervalWork,history.heldEffort*(history.endpointPosition-history.sampledPosition),policy.agreement),
                  ControlArithmetic.agrees(history.disturbanceIntervalWork,plant.disturbanceNewtons*(history.endpointPosition-history.sampledPosition),policy.agreement),
                  ControlArithmetic.agrees(history.endpointKineticEnergy-history.initialKineticEnergy,history.actuatorIntervalWork+history.disturbanceIntervalWork,policy.agreement),
                  abs(history.heldEffort) <= controller.servo.effortLimit else { throw RuntimeFailure(.invalidContributor,message:"Controller original work evidence is incompatible.") }
        } else { guard history.tick == 0 else { throw RuntimeFailure(.invalidContributor,message:"Unissued history tick differs.") } }
        return try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:ReferenceModelRevisionUpdater()).admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        // FIXME(INCOMPLETE_IMPLEMENTATION): This callable handler owns the whole controller/plant migration boundary.
        // Joint clock, actuator law, chart and physical-history compatibility must be proved before successful migration.
        throw RuntimeFailure(.incompatibleMigration,message:"Control model migration requires a joint certificate.")
    }
}
