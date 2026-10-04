import SwiftMechanics
import Testing

@Suite struct MovingBaseFailureTests {
    @Test(.timeLimit(.minutes(1))) func lateSamplerFailuresPreserveAcceptedSampleHistoryAndRandomPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture()
            for fault in [MovingMotionFaultSupplier.Fault.resetSuccess,.resetFailure,.cancel,.wrongTime,.unknown] {
                let equation=try fixture.equation(sampler:MovingMotionFaultSupplier(fault:fault))
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution()
                let prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
                let before=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Faulty motion published") }
                catch {
                    #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0)
                    switch fault {
                    case .resetSuccess,.resetFailure: #expect(error.work.failedSupplierWorkUnavailable);#expect(error.cause.code == .invalidOwnerAccess)
                    case .cancel: #expect(!error.work.failedSupplierWorkUnavailable);#expect(error.cause.code == .cancelled)
                    case .wrongTime: #expect(error.cause.code == .invalidState)
                    case .unknown: #expect(error.cause.code == .invalidState);#expect(error.work.failedSupplierWorkUnavailable);#expect(error.rejectedTrials == 0)
                    }
                }
                #expect(session.snapshot() == prefix)
                #expect(try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == before)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func realEnergyWrongAccelerationAndFailedSupplierLedgerCannotPublish() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture()
            for fault in [MovingEnergyFaultKernel.Fault.source,.resetSuccess,.resetFailure] {
                let equation=try fixture.equation(kernel:MovingEnergyFaultKernel(fault:fault))
                let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution(),prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Wrong energy published") }
                catch {
                    #expect(error.lastAccepted == prefix)
                    switch fault { case .source: #expect(error.cause.code == .invalidState);case .resetSuccess,.resetFailure: #expect(error.cause.code == .invalidOwnerAccess);#expect(error.work.failedSupplierWorkUnavailable) }
                }
                #expect(session.snapshot() == prefix)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func contextualRestartRejectsSameQvDifferentLawSamplesAndPhysicalAcceleration() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(),equation=try fixture.equation()
            let (session,continuation)=try fixture.session(equation);defer { _=session.shutdown() }
            _=try ProjectedNonlinearMechanismEvolution().advance(session,equations:equation,continuation:continuation,to:0.1)
            let prefix=session.snapshot(),old=prefix.checkpoint,physical=old.physical
            let sample=physical.prescribedAnchors[0]
            let altered=try PrescribedAnchorState(frame:sample.frame,time:sample.time,motion:.stationary(pose:sample.motion.pose))
            for change in [0,1,2] {
                let anchors:[PrescribedAnchorState],acceleration:[Double]
                switch change {
                case 0: anchors=[altered];acceleration=physical.acceleration
                case 1: anchors=[try PrescribedAnchorState(frame:sample.frame,time:sample.time+0.01,motion:sample.motion)];acceleration=physical.acceleration
                default: anchors=physical.prescribedAnchors;acceleration=physical.acceleration.map { $0+0.2 }
                }
                let changed=try KinematicState(revision:1,time:physical.time,q:physical.q,v:physical.v,acceleration:acceleration,prescribedAnchors:anchors)
                let checkpoint=try RuntimeCheckpoint(model:old.model,continuation:old.continuation,physical:changed,contributors:old.contributors,random:old.random,acceptedSteps:old.acceptedSteps)
                let codec=NativeRuntimeCheckpointCodec(),bytes=try codec.encode(checkpoint,capacity:session.configuration.capacity)
                do throws(RuntimeFailure) { _=try session.restart(bytes,codec:codec);Issue.record("Unassociated physical law accepted") }
                catch { #expect(error.code == .invalidState) }
                #expect(session.snapshot() == prefix)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func sameModelAndCoefficientIDsCannotRebindAChangedCanonicalLawDomain() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try MovingBaseFixture(),equation=try fixture.equation()
            let (source,continuation)=try fixture.session(equation);defer { _=source.shutdown() }
            _=try ProjectedNonlinearMechanismEvolution().advance(source,equations:equation,continuation:continuation,to:0.1)
            let saved=try source.checkpoint(codec:NativeRuntimeCheckpointCodec()),old=fixture.program.motions[0]
            let law=try AnalyticPrescribedMotion(frame:old.frame,parentFrame:old.parentFrame,referenceTime:old.referenceTime,initialPose:old.initialPose,
                translationRate:old.translationRate,translationAcceleration:old.translationAcceleration,rotationAxis:old.rotationAxis,
                angularRate:old.angularRate,angularAcceleration:old.angularAcceleration,minimumTime:old.minimumTime,maximumTime:10,maximumIdentifierBytes:100)
            var work=try GeometricEvolutionFixtures.work()
            let program=try PrescribedMotionProgram(motions:[law],policy:fixture.program.policy,work:&work)
            let geometry=try GeometricConstraintSystem(model:fixture.model,layout:fixture.geometry.layout,relations:fixture.geometry.relations,
                minimumPosition:fixture.geometry.minimumPosition,maximumPosition:fixture.geometry.maximumPosition,minimumTime:0,maximumTime:20,
                capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:8,maximumVelocities:8,maximumRows:8,maximumMetadataBytes:30000),work:&work,prescribedMotion:program)
            #expect(geometry.metadata != fixture.geometry.metadata)
            let changed=try GeometricEvolutionFixtures.equation(geometry,drive:equation.drive)
            let (target,_)=try fixture.session(changed);defer { _=target.shutdown() };let before=target.snapshot()
            do throws(RuntimeFailure) { _=try target.restart(saved,codec:NativeRuntimeCheckpointCodec());Issue.record("Changed law metadata accepted old history") }
            catch { #expect(error.code == .incompatibleContinuation) }
            #expect(target.snapshot() == before)
        }
    }

}
