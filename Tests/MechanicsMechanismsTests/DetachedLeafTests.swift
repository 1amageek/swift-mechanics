import SwiftMechanics
import Testing

@Suite struct DetachedLeafTests {
    @Test func actualRemovedJointFreeLayoutAndMomentum() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(q:[0.3,-0.2],v:[2,-1]),state=try model.makeState(model.descriptor.initialState)
            let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-9)
            let policy=try DetachedLeafPolicy(maximumBodies:8,maximumCoordinates:16,translation:tolerance,rotation:tolerance,linearVelocity:tolerance,
                angularVelocity:tolerance,kineticEnergy:tolerance,linearMomentum:tolerance,angularMomentum:tolerance)
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work()
            let removed=try MechanismFixtures.id(.joint,"a"),connector=try MechanismFixtures.id(.joint,"free-a")
            let transition=try ReferenceDetachedLeafTransitionBuilder().detach(model:model,state:state,joint:removed,connector:connector,
                parentAnchor:MechanismFixtures.id(.frame,"free-a-parent"),childAnchor:MechanismFixtures.id(.frame,"free-a-child"),policy:policy,
                admission:MechanismFixtures.admission(),work:&w,dynamicsWork:&d)
            #expect(!transition.target.descriptor.joints.contains(where:{$0.record.id == removed}))
            let free=try #require(transition.target.descriptor.joints.first(where:{$0.record.id == connector}))
            #expect(free.record.manifold.kind == .sixDOF)
            #expect(transition.target.tree.layout.positionCount == 8);#expect(transition.target.tree.layout.velocityCount == 7)
            #expect(transition.target.stamp.revision == 2)
            #expect(abs(transition.sourceEnergy.kineticEnergy-6) < 1e-9)
            #expect(abs(transition.targetEnergy.kineticEnergy-6) < 1e-9)
            #expect(abs(transition.targetEnergy.angularMomentum.z) < 1e-9)
            let leaf=try transition.target.initialSnapshot.body(transition.body),source=try model.initialSnapshot.body(transition.body)
            #expect(abs(leaf.motion.velocity.angular.z-2) < 1e-9)
            #expect(abs(leaf.motion.pose.rotation.z-source.motion.pose.rotation.z) < 1e-9)
            #expect(model.tree.layout.positionCount == 2);#expect(model.descriptor.joints.contains(where:{$0.record.id == removed}))
            let longConnector=try MechanismFixtures.id(.joint,String(repeating:"x",count:model.policy.maximumIdentifierBytes+1))
            let parent=try MechanismFixtures.id(.frame,"new-parent"),child=try MechanismFixtures.id(.frame,"new-child"),admission=try MechanismFixtures.admission()
            let previousDynamics=d.operations
            do throws(MechanismError) {
                _=try ReferenceDetachedLeafTransitionBuilder().detach(model:model,state:state,joint:removed,connector:longConnector,
                    parentAnchor:parent,childAnchor:child,policy:policy,admission:admission,work:&w,dynamicsWork:&d)
                Issue.record("Over-capacity detached metadata accepted.")
            } catch {
                if case .capacityExceeded=error {} else { Issue.record("Unexpected detached metadata failure.") }
                #expect(d.operations == previousDynamics)
            }
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}

extension DetachedLeafTests {
    @Test func actualAtomicThresholdBreakCheckpointReplayAndNoSecondBreak() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let model=try MechanismFixtures.model(),equation=try MechanismFixtures.equation(model)
            let (session,_)=try MechanismFixtures.session(model,equation:equation);defer { _=session.shutdown() }
            let accepted=session.snapshot(),system=try MechanismFixtures.system(model)
            var w=try MechanismFixtures.work(),d=try MechanismFixtures.work(),r=try MechanismFixtures.work(),l=try MechanismFixtures.work()
            let reaction=try MassWeightedMechanismSolver().acceleration(system,sample:MechanismFixtures.sample(),drive:[6,0],policy:MechanismFixtures.policy(),work:&w,dynamicsWork:&d,rankWork:&r,linearWork:&l)
            let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-9)
            let policy=try DetachedLeafPolicy(maximumBodies:8,maximumCoordinates:16,translation:tolerance,rotation:tolerance,linearVelocity:tolerance,
                angularVelocity:tolerance,kineticEnergy:tolerance,linearMomentum:tolerance,angularMomentum:tolerance)
            let transition=try ReferenceDetachedLeafTransitionBuilder().detach(model:model,state:accepted.physical,joint:MechanismFixtures.id(.joint,"a"),
                connector:MechanismFixtures.id(.joint,"free-a"),parentAnchor:MechanismFixtures.id(.frame,"free-a-parent"),childAnchor:MechanismFixtures.id(.frame,"free-a-child"),
                policy:policy,admission:MechanismFixtures.admission(),work:&w,dynamicsWork:&d)
            let breaker=RuntimeMechanismBreak()
            let below=try breaker.prepare(source:accepted,transition:transition,reaction:reaction,thresholdSI:3,eventID:7,maximumEventBytes:1024,work:&w)
            #expect(below == nil);#expect(session.snapshot() == accepted)
            let prepared=try #require(breaker.prepare(source:accepted,transition:transition,reaction:reaction,thresholdSI:1,eventID:7,maximumEventBytes:1024,work:&w))
            let current=session.configuration
            let configuration=try RuntimeConfiguration(continuation:current.continuation,requiredContributors:prepared.contributor.schemas,capacity:current.capacity,determinism:current.determinism,workload:current.workload)
            let handler=try ReferenceRuntimeCheckpointHandler(contributors:prepared.contributor,revisions:ReferenceModelRevisionUpdater())
            let result=try breaker.publish(prepared,session:session,configuration:configuration,contributors:[prepared.contributor.record],checkpoints:handler)
            #expect(result.physical.stamp.revision == 2);#expect(result.checkpoint.acceptedSteps == accepted.checkpoint.acceptedSteps+1)
            #expect(result.checkpoint.random == accepted.checkpoint.random);#expect(result.checkpoint.physical.time == accepted.checkpoint.physical.time)
            #expect(result.checkpoint.physical.q.count == 8 && result.checkpoint.physical.v.count == 7)
            #expect(prepared.contributor.event.metric == .torque);#expect(abs(prepared.contributor.event.observed+2) < 1e-9)
            let bytes=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
            _=try session.restart(bytes,codec:NativeRuntimeCheckpointCodec())
            #expect(session.snapshot() == result)
            do throws(MechanismError) { _=try breaker.publish(prepared,session:session,configuration:configuration,contributors:[prepared.contributor.record],checkpoints:handler);Issue.record("Repeated source break accepted.") }
            catch { #expect(session.snapshot() == result) }
        } else { Issue.record("Required Mutex platform baseline unavailable.") }
    }
}
