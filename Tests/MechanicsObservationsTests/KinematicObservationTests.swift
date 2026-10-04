import SwiftMechanics
import Testing

@Suite struct KinematicObservationTests {
    @Test func analyticOffsetGeometricMotionAndPose() throws {
        let model=try ObservationFixtures.model(q:[Double.pi/2],v:[2],a:[3]),source=try ObservationFixtures.source(model)
        let mount=try ObservationFixtures.mount(offset:Vector3(2,0,0),angle:Double.pi/2)
        var work=try ObservationFixtures.work()
        let result=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:ObservationFixtures.policy(),work:&work)
        #expect(try result.sensorToWorld.translation.subtracting(Vector3(0,2,0)).magnitude() < 1e-12)
        #expect(try result.velocity.linear.subtracting(Vector3(-4,0,0)).magnitude() < 1e-12)
        #expect(try result.acceleration.linear.subtracting(Vector3(-6,-8,0)).magnitude() < 1e-12)
        #expect(try result.velocity.angular == Vector3(0,0,2));#expect(try result.acceleration.angular == Vector3(0,0,3))
        #expect(result.header.timeSeconds == 2);#expect(result.header.model == model.stamp)
        #expect(result.header.expressedFrame == model.tree.worldFrame)
        #expect(result.linearAccelerationUnit == .acceleration)
        #expect(result.header.accelerationAuthority == .suppliedState)
        let signed=try ReferenceKinematicObserver(composer:SignEquivalentFrameComposer())
            .motion(source:source,mount:mount,policy:ObservationFixtures.policy(),work:&work)
        #expect(try signed.sensorToWorld.rotation.matrix() == result.sensorToWorld.rotation.matrix())
        #expect(signed.sensorToWorld.translation == result.sensorToWorld.translation)
        #expect(signed.velocity == result.velocity && signed.acceleration == result.acceleration)
    }
    @Test func encodersPublishSIAndDistinctQuaternionCounts() throws {
        let scalar=try ObservationFixtures.source(ObservationFixtures.model(kind:.prismatic,q:[2],v:[3],a:[4]))
        let joint=try ObservationFixtures.id(.joint,"joint"),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        let observer=ReferenceKinematicObserver()
        let linear=try observer.encoder(source:scalar,joint:joint,policy:policy,work:&work)
        #expect(linear.positions == [2]);#expect(linear.coordinateRates == [3]);#expect(linear.accelerations == [4])
        #expect(linear.positionUnits == [.length]);#expect(linear.velocityUnits == [.velocity]);#expect(linear.accelerationUnits == [.acceleration])
        let free=try ObservationFixtures.source(ObservationFixtures.model(kind:.sixDOF,q:[1,2,3,1,0,0,0],v:[4,5,6,0,0,2],a:[7,8,9,0,0,3]))
        let encoded=try observer.encoder(source:free,joint:joint,policy:policy,work:&work)
        #expect(encoded.positions.count == 7);#expect(encoded.velocities.count == 6);#expect(encoded.coordinateRates == [4,5,6,0,0,0,1])
        #expect(encoded.positionUnits[3] == .dimensionless)
        #expect(encoded.coordinateRateUnits[3] == PhysicalDimension(time:-1))
        #expect(encoded.velocityUnits[5] == PhysicalDimension(time:-1,angle:1))
        #expect(encoded.velocityConvention == .parentLinearAndBodyAngular)
    }
    @Test func currentCapacityCancellationAndLongMountRejectBeforeSupplier() throws {
        let source=try ObservationFixtures.source(ObservationFixtures.model()),mount=try ObservationFixtures.mount()
        let lowered=try ObservationPolicy(maximumBodies:1,maximumCoordinates:16,maximumReactionRows:16,maximumMetadataBytes:512)
        var work=try ObservationFixtures.work()
        do throws(ObservationError) { _=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:lowered,work:&work);Issue.record("Lowered body bound ignored.") }
        catch { if case .capacityExceeded=error {} else { Issue.record("Unexpected bound error.") } }
        #expect(work.operations == 0)
        let cancelled=try ObservationFixtures.policy(cancelled:true)
        do throws(ObservationError) { _=try ReferenceKinematicObserver().motion(source:source,mount:mount,policy:cancelled,work:&work);Issue.record("Cancellation ignored.") }
        catch { if case .cancelled=error {} else { Issue.record("Unexpected cancel error.") } }
        let long=try ObservationMount(sensor:ObservationFixtures.id(.sensor,String(repeating:"x",count:513)),body:mount.body,sensorFrame:mount.sensorFrame,sensorToBody:mount.sensorToBody)
        let observer=ReferenceKinematicObserver(composer:FailingFrameComposer()),policy=try ObservationFixtures.policy()
        do throws(ObservationError) { _=try observer.motion(source:source,mount:long,policy:policy,work:&work);Issue.record("Long metadata accepted.") }
        catch { if case .capacityExceeded=error {} else { Issue.record("Supplier ran before bounded metadata admission.") } }
    }
}
