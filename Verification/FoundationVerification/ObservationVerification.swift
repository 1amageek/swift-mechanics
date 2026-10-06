import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    static func verifyObservations() throws {
        try verifyMountedKinematicsAndIMU()
        try verifyIdentifiedWrench()
        try verifySuccessfulSupplierRefusal()
    }
    @inline(never)
    private static func verifyMountedKinematicsAndIMU() throws {
        let source = try ObservationProbeContext.source(), mount = try ObservationProbeContext.mount(offset: 2)
        let policy = try ObservationProbeContext.policy()
        var work = try ObservationProbeContext.work()
        let kinematics: any KinematicObserving = ReferenceKinematicObserver()
        let motion = try kinematics.motion(source: source, mount: mount, policy: policy, work: &work)
        try require(abs(motion.velocity.linear.x) < 1e-10 && abs(motion.velocity.linear.y - 4) < 1e-10)
        try require(abs(motion.acceleration.linear.x + 8) < 1e-10 && abs(motion.acceleration.linear.y - 6) < 1e-10)
        let encoder = try kinematics.encoder(source: source,
            joint: EntityID(kind: .joint, key: "compile-probe-hinge"), policy: policy, work: &work)
        try require(encoder.positions == [0] && encoder.velocities == [2] && encoder.accelerations == [3])
        try require(encoder.positionUnits == [.angle] && encoder.timeSeconds == 2)
        let imu: any RigidIMUObserving = ReferenceRigidIMUObserver()
        let result = try imu.sample(source: source, mount: mount, gravity: ObservationProbeContext.gravity(source),
            policy: policy, work: &work)
        try require(abs(result.specificForceSensor.x - 6) < 1e-10 && abs(result.specificForceSensor.y - 8) < 1e-10)
        try require(abs(result.angularVelocitySensor.z - 2) < 1e-10 && result.header.accelerationAuthority == .suppliedState)
        let stale = try ObservationProbeContext.gravity(source, time: 3)
        var refused = false
        do throws(ObservationError) {
            _ = try imu.sample(source: source, mount: mount, gravity: stale, policy: policy, work: &work)
        } catch {
            guard case .staleGravity = error else { throw FoundationVerificationError.analyticCheckFailed }
            refused = true
        }
        try require(refused && source.state.state.time == 2)
    }
    @inline(never)
    private static func verifySuccessfulSupplierRefusal() throws {
        let source = try ObservationProbeContext.source()
        let mount = try ObservationProbeContext.mount(offset: 2)
        let observer: any KinematicObserving = ReferenceKinematicObserver(
            composer: ObservationProbeContext.UnrelatedMotionComposer())
        var work = try ObservationProbeContext.work()
        let before = work.operations
        let policy = try ObservationProbeContext.policy()
        var refused = false
        do throws(ObservationError) {
            _ = try observer.motion(source: source, mount: mount,
                policy: policy, work: &work)
        } catch {
            guard case .invalidSupplierEvidence = error,
                  !error.failedSupplierWorkUnavailable else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            refused = true
        }
        try require(refused && work.operations > before)
        try require(source.state.state.q == [0] && source.state.state.v == [2])
        try require(source.state.state.acceleration == [3] && source.state.state.time == 2)
    }
    @inline(never)
    private static func verifyIdentifiedWrench() throws {
        let source = try ObservationProbeContext.source(), mount = try ObservationProbeContext.mount(offset: 1)
        let input = try IdentifiedPhysicalWrench(path: EntityID(kind: .load, key: "observation-physical-path"),
            body: mount.body, model: source.model.stamp, timeSeconds: 2, frame: source.snapshot.tree.worldFrame,
            referencePoint: .zero, wrench: SpatialWrench(torque: Vector3(0, 0, 3), force: Vector3(0, 20, 0)),
            temporalMeaning: .force)
        var work = try ObservationProbeContext.work()
        let observer: any WrenchObserving = ReferenceWrenchObserver()
        let result = try observer.physical(source: source, mount: mount, input: input,
            options: WrenchObservationOptions(), gravity: nil, policy: ObservationProbeContext.policy(), work: &work)
        try require(abs(result.wrench.force.x - 20) < 1e-10 && abs(result.wrench.force.y) < 1e-10)
        try require(abs(result.wrench.torque.z + 17) < 1e-10 && result.path == input.path)
        try require(result.forceUnit == .force && result.header.timeSeconds == 2)
    }
}
