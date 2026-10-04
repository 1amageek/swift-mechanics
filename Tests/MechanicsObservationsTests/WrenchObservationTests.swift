import SwiftMechanics
import Testing

@Suite struct WrenchObservationTests {
    @Test func actualScalarStaticSupportAndSolvedAccelerationAuthority() throws {
        let model=try ObservationFixtures.model(kind:.prismatic),reaction=try ObservationFixtures.supported(model)
        let baseline=try ObservationFixtures.source(model),mount=try ObservationFixtures.mount(angle:Double.pi/2),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        let solved=try ReferenceObservationSourcePreparer().prepare(model:model,state:baseline.state,solved:reaction,policy:policy,work:&work)
        let observed=try ReferenceWrenchObserver().axialReaction(source:solved,mount:mount,joint:ObservationFixtures.id(.joint,"joint"),motion:reaction,
            temporal:.force,sign:.intoBody,policy:policy,work:&work)
        #expect(abs(observed.effort-20) < 1e-10)
        #expect(observed.effortUnit == .force);#expect(observed.reactionNullity == 0);#expect(observed.retainedRowIDs == [1])
        #expect(try observed.axisSensor.subtracting(Vector3(1,0,0)).magnitude() < 1e-12)
        #expect(observed.header.accelerationAuthority == .constraintSolved)
        let imu=try ReferenceRigidIMUObserver().sample(source:solved,mount:mount,gravity:ObservationFixtures.gravity(solved,value:Vector3(0,-10,0)),policy:policy,work:&work)
        #expect(try imu.specificForceSensor.subtracting(Vector3(10,0,0)).magnitude() < 1e-10)
        #expect(try imu.worldAcceleration.magnitude() < 1e-10)
    }
    @Test func shiftedRotatedPhysicalWrenchSignAndTrueCOMGravitySubtraction() throws {
        let source=try ObservationFixtures.source(ObservationFixtures.model(kind:.prismatic,com:Vector3(0.5,0,0)))
        let mount=try ObservationFixtures.mount(offset:Vector3(1,0,0),angle:Double.pi/2),policy=try ObservationFixtures.policy()
        let input=try IdentifiedPhysicalWrench(path:ObservationFixtures.id(.load,"physical-path"),body:mount.body,model:source.model.stamp,
            timeSeconds:source.state.state.time,frame:source.snapshot.tree.worldFrame,referencePoint:.zero,
            wrench:SpatialWrench(torque:Vector3(0,0,3),force:Vector3(0,20,0)),temporalMeaning:.force)
        let observer=ReferenceWrenchObserver();var work=try ObservationFixtures.work()
        let measured=try observer.physical(source:source,mount:mount,input:input,options:WrenchObservationOptions(),policy:policy,work:&work)
        #expect(try measured.wrench.force.subtracting(Vector3(20,0,0)).magnitude() < 1e-12)
        #expect(abs(measured.wrench.torque.z+17) < 1e-12)
        let compensated=try observer.physical(source:source,mount:mount,input:input,options:WrenchObservationOptions(sign:.outOfBody,gravityCompensation:.subtractBodyGravity),
            gravity:ObservationFixtures.gravity(source,value:Vector3(0,-10,0)),policy:policy,work:&work)
        #expect(try compensated.wrench.force.subtracting(Vector3(-40,0,0)).magnitude() < 1e-12)
        #expect(abs(compensated.wrench.torque.z-27) < 1e-12)
        #expect(compensated.forceUnit == .force);#expect(compensated.torqueUnit == .energy)
        // Independent virtual-power invariance at the shifted origin.
        let motion=SpatialMotion(angular:try Vector3(0,0,2),linear:try Vector3(4,5,0))
        let atSensor=SpatialMotion(angular:motion.angular,linear:try motion.linear.adding(motion.angular.cross(mount.sensorToBody.translation)))
        let expressed=SpatialMotion(angular:try mount.sensorToBody.rotation.conjugated().rotating(atSensor.angular),linear:try mount.sensorToBody.rotation.conjugated().rotating(atSensor.linear))
        #expect(abs(try input.wrench.power(against:motion)-measured.wrench.power(against:expressed)) < 1e-10)
    }
    @Test func impulseIsNotAverageForceAndMissingDecompositionRejects() throws {
        let model=try ObservationFixtures.model(kind:.prismatic,v:[3]),source=try ObservationFixtures.source(model),impulse=try ObservationFixtures.supported(model,impulse:true)
        let mount=try ObservationFixtures.mount(),joint=try ObservationFixtures.id(.joint,"joint"),policy=try ObservationFixtures.policy()
        let observer=ReferenceWrenchObserver();var work=try ObservationFixtures.work()
        let read=try observer.axialReaction(source:source,mount:mount,joint:joint,motion:impulse,temporal:.impulse,sign:.intoBody,policy:policy,work:&work)
        #expect(abs(read.effort+6) < 1e-10);#expect(read.effortUnit == PhysicalDimension(length:1,mass:1,time:-1))
        #expect(read.header.temporalMeaning == .instantaneousImpulse)
        do throws(ObservationError) { _=try observer.axialReaction(source:source,mount:mount,joint:joint,motion:impulse,temporal:.force,sign:.intoBody,policy:policy,work:&work);Issue.record("Impulse presented as force.") }
        catch { if case .temporalMismatch=error {} else { Issue.record("Wrong temporal failure.") } }
        do throws(ObservationError) { try observer.bearingReaction() }
        catch { if case .unsupportedDecomposition=error {} else { Issue.record("Bearing decomposition fabricated.") } }
        let input=try IdentifiedPhysicalWrench(path:ObservationFixtures.id(.load,"impulse-path"),body:mount.body,model:model.stamp,timeSeconds:2,frame:model.tree.worldFrame,referencePoint:.zero,
            wrench:SpatialWrench(torque:.zero,force:Vector3(0,-6,0)),temporalMeaning:.impulse)
        let gravity=try ObservationFixtures.gravity(source)
        do throws(ObservationError) { _=try observer.physical(source:source,mount:mount,input:input,options:WrenchObservationOptions(gravityCompensation:.subtractBodyGravity),gravity:gravity,policy:policy,work:&work);Issue.record("Gravity impulse compensation accepted.") }
        catch { if case .temporalMismatch=error {} else { Issue.record("Wrong impulse compensation failure.") } }
    }
}
