import SwiftMechanics
import Testing

@Suite struct IMUObservationTests {
    @Test func actualFreeFallAndStationarySupportSpecificForce() throws {
        let fall=try ObservationFixtures.source(ObservationFixtures.model(kind:.prismatic,q:[2],v:[3],a:[-10]))
        let rest=try ObservationFixtures.source(ObservationFixtures.model(kind:.prismatic,q:[2],v:[0],a:[0]))
        let mount=try ObservationFixtures.mount(angle:Double.pi/2),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        let imu=ReferenceRigidIMUObserver()
        let falling=try imu.sample(source:fall,mount:mount,gravity:ObservationFixtures.gravity(fall,value:Vector3(0,-10,0)),policy:policy,work:&work)
        #expect(try falling.specificForceSensor.magnitude() < 1e-12)
        #expect(try falling.worldAcceleration == Vector3(0,-10,0))
        let stationary=try imu.sample(source:rest,mount:mount,gravity:ObservationFixtures.gravity(rest,value:Vector3(0,-10,0)),policy:policy,work:&work)
        #expect(try stationary.specificForceSensor.subtracting(Vector3(10,0,0)).magnitude() < 1e-12)
        #expect(stationary.header.expressedFrame == mount.sensorFrame)
    }
    @Test func offCenterRotationAndInstantaneousGravityGradient() throws {
        let source=try ObservationFixtures.source(ObservationFixtures.model(q:[0],v:[2],a:[3]))
        let mount=try ObservationFixtures.mount(offset:Vector3(2,0,0),angle:Double.pi/2),policy=try ObservationFixtures.policy()
        var work=try ObservationFixtures.work()
        let imu=ReferenceRigidIMUObserver()
        let actual=try imu.sample(source:source,mount:mount,gravity:ObservationFixtures.gravity(source),policy:policy,work:&work)
        #expect(try actual.worldAcceleration.subtracting(Vector3(-8,6,0)).magnitude() < 1e-12)
        #expect(try actual.specificForceSensor.subtracting(Vector3(6,8,0)).magnitude() < 1e-12)
        #expect(try actual.angularVelocitySensor == Vector3(0,0,2))
        let field=try AffineGravity(frame:source.snapshot.tree.worldFrame,accelerationAtOrigin:.zero,gradient:Matrix3(1,0,0,0,0,0,0,0,0),uniformTimeDerivative:Vector3(100,0,0))
        let bound=try ObservationGravity(model:source.model.stamp,timeSeconds:source.state.state.time,field:field)
        let gradient=try imu.sample(source:source,mount:mount,gravity:bound,policy:policy,work:&work)
        #expect(try gradient.specificForceSensor.subtracting(Vector3(6,10,0)).magnitude() < 1e-12)
    }
    @Test func gravityTimeMismatchAndUnknownSupplierWorkFail() throws {
        let source=try ObservationFixtures.source(ObservationFixtures.model()),mount=try ObservationFixtures.mount(),policy=try ObservationFixtures.policy()
        let original=try ObservationFixtures.gravity(source)
        let stale=try ObservationGravity(model:original.model,timeSeconds:original.timeSeconds+1,field:original.field)
        var work=try ObservationFixtures.work()
        do throws(ObservationError) { _=try ReferenceRigidIMUObserver().sample(source:source,mount:mount,gravity:stale,policy:policy,work:&work);Issue.record("Stale gravity accepted.") }
        catch { if case .staleGravity=error {} else { Issue.record("Wrong stale gravity failure.") } }
        let imu=ReferenceRigidIMUObserver(kinematics:ResettingKinematicObserver())
        do throws(ObservationError) { _=try imu.sample(source:source,mount:mount,gravity:original,policy:policy,work:&work);Issue.record("Ledger reset accepted.") }
        catch { #expect(error.failedSupplierWorkUnavailable);if case .supplierLedgerReplaced=error {} else { Issue.record("Wrong ledger failure.") } }
        let failing=ReferenceRigidIMUObserver(kinematics:ResettingKinematicObserver(throwsAfterReset:true))
        let failurePrefix=work.operations
        do throws(ObservationError) { _=try failing.sample(source:source,mount:mount,gravity:original,policy:policy,work:&work);Issue.record("Failed supplier hid ledger reset.") }
        catch { #expect(error.failedSupplierWorkUnavailable);if case .supplierLedgerReplaced=error {} else { Issue.record("Wrong failed-reset refusal.") } }
        #expect(work.operations > failurePrefix)
        let rotating=try ObservationFixtures.source(ObservationFixtures.model(q:[0],v:[2],a:[3]))
        let offset=try ObservationFixtures.mount(offset:Vector3(2,0,0))
        let field=try ObservationFixtures.gravity(rotating),before=work.operations
        do throws(ObservationError) {
            _=try ReferenceRigidIMUObserver(kinematics:ChangedMountKinematicObserver())
                .sample(source:rotating,mount:offset,gravity:field,policy:policy,work:&work)
            Issue.record("Header-matching motion for another mount was published.")
        } catch {
            if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong changed-mount supplier failure.") }
            #expect(!error.failedSupplierWorkUnavailable)
        }
        #expect(work.operations > before)
        #expect(rotating.state.state.v == [2] && rotating.state.state.acceleration == [3])
    }
}
