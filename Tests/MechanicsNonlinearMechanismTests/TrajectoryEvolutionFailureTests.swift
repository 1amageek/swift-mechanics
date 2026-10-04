import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(2))) struct TrajectoryEvolutionFailureTests {
    @Test func boundaryWrongNilLateResetCancellationAndUnknownWorkCannotPublishAcrossKnot() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryEvolutionFixtures(planar:true,piecewise:true)
            for fault in [TrajectoryFaultBoundaryQuery.Fault.wrongNil,.late,.resetFailure,.cancel,.unknown] {
                let query=TrajectoryFaultBoundaryQuery(fault),equation=try fixture.equation(query:query)
                let (session,continuation)=try fixture.session(equation,step:0.7);defer { _=session.shutdown() }
                let prefix=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.7).accepted
                let codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
                do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:1.4);Issue.record("Faulty boundary published") }
                catch {
                    #expect(error.lastAccepted == prefix && error.work.supplierArithmeticCharged > 0 && error.rejectedTrials == 0)
                    switch fault {
                    case .wrongNil,.late:#expect(error.cause.code == .invalidState)
                    case .resetFailure:#expect(error.cause.code == .invalidOwnerAccess && error.work.failedSupplierWorkUnavailable)
                    case .cancel:#expect(error.cause.code == .cancelled)
                    case .unknown:#expect(error.work.failedSupplierWorkUnavailable)
                    case .none:Issue.record("No fault requested")
                    }
                }
                #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == before)
            }
        }
    }
    @Test func newSamplerLedgerAndOriginalSourceFailuresRetainAcceptedBytes() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryEvolutionFixtures(planar:false,piecewise:false)
            for fault in [TrajectoryFaultBaseSampler.Fault.wrongTime,.resetSuccess,.resetFailure,.cancel,.unknown] {
                let equation=try fixture.equation(sampler:TrajectoryFaultBaseSampler(fault:fault)),(session,continuation)=try fixture.session(equation,step:0.02);defer { _=session.shutdown() }
                let prefix=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.04).accepted
                let codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
                do throws(NonlinearMechanismFailure) { _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.08);Issue.record("Faulty new sampler published") }
                catch {
                    #expect(error.lastAccepted == prefix && error.work.supplierArithmeticCharged > 0)
                    switch fault {
                    case .wrongTime:#expect(error.cause.code == .invalidState)
                    case .resetSuccess,.resetFailure:#expect(error.cause.code == .invalidOwnerAccess && error.work.failedSupplierWorkUnavailable)
                    case .cancel:#expect(error.cause.code == .cancelled)
                    case .unknown:#expect(error.work.failedSupplierWorkUnavailable && error.rejectedTrials == 0)
                    }
                }
                #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == before)
            }
        }
    }
    @Test func futureLawChangeWithSameRevisionAndCurrentPhysicalJetsRefusesExactOriginalHistory() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryEvolutionFixtures(planar:true,piecewise:true),equation=try fixture.equation(),(source,continuation)=try fixture.session(equation);defer { _=source.shutdown() }
            _=try ProjectedNonlinearMechanismEvolution().advance(source,equations:equation,continuation:continuation,to:0.4)
            let codec=NativeRuntimeCheckpointCodec(),saved=try source.checkpoint(codec:codec)
            let changed=try TrajectoryEvolutionFixtures(planar:true,piecewise:true,futureChange:0.2),changedEquation=try changed.equation(),(target,_)=try changed.session(changedEquation);defer { _=target.shutdown() }
            #expect(changed.model.stamp == fixture.model.stamp)
            let oldSample=try fixture.sample(0.4),newSample=try changed.sample(0.4)
            #expect(oldSample.q == newSample.q && oldSample.v == newSample.v && oldSample.a == newSample.a)
            let before=try target.checkpoint(codec:codec)
            do throws(RuntimeFailure) { _=try target.restart(saved,codec:codec);Issue.record("Changed future trajectory rebound old history") }
            catch { #expect(error.code == .incompatibleContinuation) }
            #expect(try target.checkpoint(codec:codec) == before)
        }
    }
    @Test func boundaryCapacityAndForgedTangentAccelerationKeepWholeRandomHistoryPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try TrajectoryEvolutionFixtures(planar:true,piecewise:true,descendants:true),query=TrajectoryFaultBoundaryQuery(),equation=try fixture.equation(query:query)
            let (session,continuation)=try fixture.session(equation,step:0.02);defer { _=session.shutdown() }
            let final=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.1).accepted
            let codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec),count=query.callCount()
            let budget=try NumericalBudget(scalarStorage:1,arithmeticOperations:1,iterations:1)
            do throws(RuntimeFailure) {
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    _ = try trial.nextRandom();var work=NumericalWork(budget:budget)
                    _=try equation.nextBoundary(after:0.7,through:1.4,work:&work,control:control);return .accept
                }
                Issue.record("Unadmitted query entered")
            } catch { #expect(error.code == .capacityExceeded) }
            #expect(query.callCount() == count);#expect(try session.checkpoint(codec:codec) == before)
            let old=final.checkpoint,state=old.physical
            var acceleration=state.acceleration;acceleration[fixture.first]+=0.2;acceleration[fixture.second]+=0.2
            let changed=try KinematicState(revision:state.revision,time:state.time,q:state.q,v:state.v,acceleration:acceleration)
            let checkpoint=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:changed,contributors:old.contributors,random:old.random,acceptedSteps:old.acceptedSteps)
            let forged=try codec.encode(checkpoint,capacity:session.configuration.capacity)
            do throws(RuntimeFailure) { _=try session.restart(forged,codec:codec);Issue.record("Row-consistent wrong physical acceleration accepted") }
            catch { #expect(error.code == .invalidState) }
            #expect(session.snapshot() == final);#expect(try session.checkpoint(codec:codec) == before)
        }
    }

}
