import SwiftMechanics
import Testing

@Suite struct DriveTests {
    @Test func effortVelocityPositionAreRealDistinctEffortLaws() throws {
        let binding=try ActuationFixtures.binding(),law=try ActuationFixtures.servo(binding,effort:100)
        let evaluator:any DriveEvaluating=ReferenceDriveEvaluator()
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical()
        for (mode,target,expected) in [(DriveMode.effort,5.0,5.0),(.velocity,3.0,4.4),(.position,2.0,5.35)] {
            let state=try ActuationFixtures.state(binding,mode:mode),sample=try ActuationFixtures.sample(binding,position:0.25,velocity:1)
            let response=try evaluator.step(law:law,state:state,sample:sample,command:DriveCommand(mode:mode,value:target),dt:0.1,
                energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
            #expect(abs(response.appliedEffort-expected) < 1e-12)
            #expect(response.power == response.appliedEffort && response.energy.sourceWork == response.energy.mechanicalWork)
            #expect(state.primary == 0 && response.state.time == 0.1)
        }
    }
    @Test func saturationConditionalAntiWindupRecoveryAndSpeedBraking() throws {
        let binding=try ActuationFixtures.binding(),law=try ActuationFixtures.servo(binding)
        let state=try ActuationFixtures.state(binding,mode:.position),evaluator:any DriveEvaluating=ReferenceDriveEvaluator()
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical()
        let high=try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.position,value:100),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(high.clipped && high.requestedEffort == 410 && high.appliedEffort == 3 && high.state.primary == 0)
        let recovery=try evaluator.step(law:law,state:high.state,sample:ActuationFixtures.sample(binding,time:1),command:DriveCommand(mode:.position,value:0.25),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(!recovery.clipped && recovery.appliedEffort == 1.5 && recovery.state.primary == 0.5)
        let effortState=try ActuationFixtures.state(binding)
        let overspeed=try evaluator.step(law:law,state:effortState,sample:ActuationFixtures.sample(binding,velocity:10),command:DriveCommand(mode:.effort,value:2),dt:0,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(overspeed.appliedEffort == 0 && overspeed.clipped && overspeed.state == effortState)
        let brake=try evaluator.step(law:law,state:effortState,sample:ActuationFixtures.sample(binding,velocity:10),command:DriveCommand(mode:.effort,value:-2),dt:0,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(brake.appliedEffort == -2 && brake.power == -20)
    }
    @Test func backwardEulerFilterDeadbandAndRestoredState() throws {
        let binding=try ActuationFixtures.binding(),law=try ActuationFixtures.servo(binding,integralGain:0,effort:100,filter:1)
        let initial=try ActuationFixtures.state(binding,mode:.velocity),evaluator:any DriveEvaluating=ReferenceDriveEvaluator()
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical()
        let first=try evaluator.step(law:law,state:initial,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.velocity,value:8),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(first.state.secondary == 4 && first.appliedEffort == 8)
        let second=try evaluator.step(law:law,state:first.state,sample:ActuationFixtures.sample(binding,time:1),command:DriveCommand(mode:.velocity,value:8),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(second.state.secondary == 6 && second.appliedEffort == 12)
        let replay=try evaluator.step(law:law,state:first.state,sample:ActuationFixtures.sample(binding,time:1),command:DriveCommand(mode:.velocity,value:8),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(replay == second)
        let zero=try evaluator.step(law:ActuationFixtures.servo(binding,filter:0),state:initial,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.velocity,value:0.005),dt:1,
            energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical)
        #expect(zero.appliedEffort == 0)
    }
    @Test func prescribedCommandRequiresActualPrescribedAuthorityAndDoesNotInventReaction() throws {
        let evaluator:any DriveEvaluating=ReferenceDriveEvaluator(),binding=try ActuationFixtures.binding(authority:.prescribedMotion)
        var work=try ActuationFixtures.work()
        let command=try evaluator.prescribedVelocity(binding:binding,model:ActuationFixtures.model(authority:.prescribedMotion),time:0,requested:5,speedLimit:2,work:&work)
        #expect(command.appliedVelocity == 2 && command.clipped)
        #expect(throws:ActuationError.incompatibleAuthority) { try evaluator.prescribedVelocity(binding:ActuationFixtures.binding(),model:ActuationFixtures.model(),time:0,requested:5,speedLimit:2,work:&work) }
    }
    @Test func staleModeDomainBudgetAndCancellationFailures() async throws {
        let binding=try ActuationFixtures.binding(),state=try ActuationFixtures.state(binding),law=try ActuationFixtures.servo(binding),evaluator:any DriveEvaluating=ReferenceDriveEvaluator()
        var work=try ActuationFixtures.work(),numerical=try ActuationFixtures.numerical()
        #expect(throws:ActuationError.staleTime) { try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding,time:1),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical) }
        #expect(throws:ActuationError.incompatibleMode) { try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.position,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical) }
        work=ActuationWork(budget:try ActuationFixtures.budget(work:0))
        #expect(throws:ActuationError.workExhausted) { try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical) }
        work=try ActuationFixtures.work();numerical=try ActuationFixtures.numerical(operations:0)
        #expect(throws:ActuationError.self) { try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numerical) }
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            var work=try ActuationFixtures.work(),numeric=try ActuationFixtures.numerical()
            #expect(throws:ActuationError.cancelled) { try evaluator.step(law:law,state:state,sample:ActuationFixtures.sample(binding),command:DriveCommand(mode:.effort,value:1),dt:1,energyTolerance:ActuationFixtures.tolerance(),work:&work,numerical:&numeric) }
        };try await task.value
    }
}
