import SwiftMechanics
import Testing
struct FluidCancellationTests {
    @Test func actualCompletedSolverCancellationCannotPublishField() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let owner=FluidCancellationOwner(),policy=try FluidFixtures.policy(cancel:{owner.read()})
            let c=try FluidFixtures.channel(),b=try FluidFixtures.boundary(gradient:-2),old=try FluidFixtures.state(channel:c,boundary:b)
            let solver:any FluidEvolving=ReferenceViscousChannelSolver(linear:CancellingFluidSolver(owner:owner),fields:ReferenceFluidFieldBuilder())
            var work=try FluidFixtures.work()
            FluidFixtures.failure(.cancelled) { () throws(FluidError) in _=try solver.step(state:old,boundary:b,duration:0.1,policy:policy,work:&work) }
            #expect(work.operations > 80); #expect(owner.read());#expect(old.time == 0)
        } else { Issue.record("Cancellation owner verification requires Mutex availability.") }
    }

    @Test func actualRuntimeCancellationAfterSolvePreservesAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try FluidRuntimeFixture(),initial=try fixture.accepted()
            let model=fixture.model,codec=fixture.codec,boundary=try FluidFixtures.boundary(gradient:-2),policy=try FluidFixtures.policy()
            let op:any FluidTrialOperating=ReferenceFluidTrialOperator(codec:codec,evolution:ReferenceViscousChannelSolver(linear:RuntimeCancellingFluidSolver(session:fixture.session),fields:ReferenceFluidFieldBuilder()))
            do throws(RuntimeFailure) {
                _=try fixture.session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work:NumericalWork;var bytes:FluidByteWork
                    do { work=try FluidFixtures.work();bytes=try FluidByteWork(maximumBytes:10000,maximumVisitedBytes:100000) }
                    catch { throw RuntimeFailure(.invalidInput,message:"Fixture budgets failed.") }
                    _=try op.advance(model:model,boundary:boundary,duration:0.1,policy:policy,trial:&trial,control:&control,numerical:&work,bytes:&bytes)
                    return .accept
                }
                Issue.record("Expected Runtime cancellation after actual solve")
            } catch { #expect(error.code == .cancelled) }
            #expect(try fixture.accepted() == initial);_=fixture.session.shutdown()
        } else { Issue.record("Runtime fluid cancellation verification requires Runtime availability.") }
    }
}

