import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct PrescribedRootFailureTests {
    @Test func lateBaseSupplierSourceResetCancellationAndUnknownWorkKeepExactAcceptedPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:false)
            for fault in [PrescribedRootFaultSupplier.Fault.wrongTime,.resetSuccess,.resetFailure,.cancel,.unknown] {
                let equation=try fixture.equation(sampler:PrescribedRootFaultSupplier(fault:fault))
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution(),prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.04).accepted
                let codec=NativeRuntimeCheckpointCodec(),before=try session.checkpoint(codec:codec)
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.08);Issue.record("Faulty prescribed root published") }
                catch {
                    #expect(error.lastAccepted == prefix && error.work.supplierArithmeticCharged > 0)
                    switch fault {
                    case .wrongTime:#expect(error.cause.code == .invalidState)
                    case .resetSuccess,.resetFailure:#expect(error.cause.code == .invalidOwnerAccess && error.work.failedSupplierWorkUnavailable)
                    case .cancel:#expect(error.cause.code == .cancelled && !error.work.failedSupplierWorkUnavailable)
                    case .unknown:#expect(error.work.failedSupplierWorkUnavailable && error.rejectedTrials == 0)
                    }
                }
                #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == before)
            }
        }
    }
    @Test func partitionUsesOriginalPhysicalAccelerationAndValidatesSupplierLedgersOnEitherOutcome() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:true)
            for fault in [PrescribedRootPowerFaultSupplier.Fault.acceleration,.resetSuccess,.resetFailure,.cancel] {
                let equation=try fixture.equation(partitioner:PrescribedRootPowerFaultSupplier(fault:fault))
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution(),prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.04).accepted
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.08);Issue.record("Wrong partition published") }
                catch {
                    #expect(error.lastAccepted == prefix)
                    switch fault {
                    case .acceleration:#expect(error.cause.code == .invalidState)
                    case .resetSuccess,.resetFailure:#expect(error.cause.code == .invalidOwnerAccess && error.work.failedSupplierWorkUnavailable)
                    case .cancel:#expect(error.cause.code == .cancelled)
                    }
                }
                #expect(session.snapshot() == prefix)
            }
        }
    }
    @Test func coldRestartRefusesForgedKnownAndTangentAccelerationAndPreservesBytesRandomAndHistory() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            for planar in [true,false] {
                let fixture=try PrescribedRootEvolutionFixture(planar:planar,descendants:true),equation=try fixture.equation()
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.1)
                let prefix=session.snapshot(),old=prefix.checkpoint,state=old.physical,codec=NativeRuntimeCheckpointCodec(),saved=try session.checkpoint(codec:codec)
                for change in 0..<5 {
                    var q=state.q,v=state.v,a=state.acceleration
                    switch change {
                    case 0:q[0]+=0.01
                    case 1:v[0]+=0.01
                    case 2:a[0]+=0.01
                    case 3:a[fixture.first]+=0.2;a[fixture.second]+=0.2
                    default:break
                    }
                    let changed=try KinematicState(revision:state.revision,time:state.time+(change == 4 ? 0.01 : 0),q:q,v:v,acceleration:a)
                    let checkpoint=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:changed,contributors:old.contributors,random:old.random,acceptedSteps:old.acceptedSteps)
                    let bytes=try codec.encode(checkpoint,capacity:session.configuration.capacity)
                    do throws(RuntimeFailure) { _=try session.restart(bytes,codec:codec);Issue.record("Forged prescribed physical source accepted") }
                    catch { #expect(error.code == .invalidState) }
                    #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:codec) == saved)
                }
                let (cold,coldContinuation)=try fixture.session(equation);defer { _=cold.shutdown() }
                _=try cold.restart(saved,codec:codec)
                let originalFinal=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.2).accepted
                let coldFinal=try ProjectedNonlinearMechanismEvolution().advance(cold,equations:equation,continuation:coldContinuation,to:0.2).accepted
                let coldCheckpoint=try cold.checkpoint(codec:codec)
                let originalCheckpoint=try session.checkpoint(codec:codec)
                #expect(coldFinal == originalFinal && coldCheckpoint == originalCheckpoint)
            }
        }
    }
    @Test func coldLawDomainAndActualInertiaChangesCannotRebindTheSameNamedModel() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:true),equation=try fixture.equation()
            let (source,continuation)=try fixture.session(equation);defer { _=source.shutdown() }
            _=try ProjectedNonlinearMechanismEvolution().advance(source,equations:equation,continuation:continuation,to:0.1)
            let codec=NativeRuntimeCheckpointCodec(),saved=try source.checkpoint(codec:codec)
            for alternate in [try PrescribedRootEvolutionFixture(planar:true,polarScale:1.1),try PrescribedRootEvolutionFixture(planar:true,maximumTime:1)] {
                let changed=try alternate.equation(),(target,_)=try alternate.session(changed);defer { _=target.shutdown() }
                let before=target.snapshot()
                do throws(RuntimeFailure) { _=try target.restart(saved,codec:codec);Issue.record("Changed physical identity accepted old continuation") }
                catch { #expect(error.code == .incompatibleContinuation) }
                #expect(target.snapshot() == before)
            }
        }
    }
    @Test func realProducerWithDifferentRootSnapshotCannotReplaceTheActualPhysicalSource() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:true)
            let equation=try fixture.equation(kernel:PlanarEvolutionFaultKernel(model:fixture.model,fault:.wrongSource))
            let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
            let evolution=ProjectedNonlinearMechanismEvolution(),prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.06).accepted
            let before=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Wrong root source published") }
            catch { #expect(error.cause.code == .invalidState && error.lastAccepted == prefix) }
            #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == before)
        }
    }
    @Test func rootDriveConflictAndCallerCapacityAreExplicitAndAtomic() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try PrescribedRootEvolutionFixture(planar:true),equation=try fixture.equation(),admission=try NonlinearMechanismFixtures.admission()
            var conflict=equation.drive;conflict[0]=1
            do throws(RuntimeFailure) {
                _=try GeometricMechanismEquation(identity:"conflict",geometry:fixture.geometry,drive:conflict,policy:equation.policy,projection:equation.projection,
                    maximumStageChartCorrection:0.01,publicationBudget:equation.publicationBudget,admission:admission,maximumIdentityBytes:100000,
                    physicalKernel:RigidEquationKernel(),prescribedRootSolver:MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel()),activeRanker:WeightedConstraintAssembler())
                Issue.record("Conflicting root drive accepted")
            } catch { #expect(error.code == .invalidInput) }
            let (session,_)=try fixture.session(equation);defer { _=session.shutdown() };let before=session.snapshot()
            let budget=try NumericalBudget(scalarStorage:1,arithmeticOperations:1,iterations:1)
            do throws(RuntimeFailure) {
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:budget)
                    _=try equation.consistent(time:0,point:before.checkpoint.physical.q+before.checkpoint.physical.v,work:&work,control:control);return .accept
                }
                Issue.record("Capacity failure published")
            } catch { #expect(error.code == .capacityExceeded) }
            #expect(session.snapshot() == before)
        }
    }
}
