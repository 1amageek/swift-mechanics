import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct RuntimeMovingAnchorFixtures {
    static func frame() throws -> EntityID { try RuntimeFixtures.id(.frame, "moving-parent") }
    static func secondaryFrame() throws -> EntityID { try RuntimeFixtures.id(.frame, "moving-child") }
    static func sample(time: Double, secondary: Bool = false) throws(RuntimeFailure) -> PrescribedAnchorState {
        do {
            let frameID = try secondary ? secondaryFrame() : frame()
            if secondary {
                return try PrescribedAnchorState(frame: frameID, time: time, motion: .stationary(pose:
                    RigidTransform(rotation: UnitQuaternion(axis: .unitX, angle: -0.2), translation: Vector3(0.1, -0.0, 0))))
            }
            let rotation = try UnitQuaternion(axis: .unitZ, angle: 0.3 + 0.4 * time + 0.1 * time * time)
            // Preserve a negative quaternion representative and signed-zero fields across continuation.
            let signed = try UnitQuaternion(unitW: -rotation.w, x: -rotation.x, y: -rotation.y, z: -rotation.z)
            let pose = RigidTransform(rotation: signed, translation: try Vector3(0.2 + 0.6 * time + 0.15 * time * time, -0.0, 0))
            return try PrescribedAnchorState(frame: frameID, time: time, motion: FrameMotion(pose: pose,
                velocity: SpatialMotion(angular: Vector3(-0.0, 0, 0.4 + 0.2 * time), linear: Vector3(0.6 + 0.3 * time, -0.0, 0)),
                acceleration: SpatialMotion(angular: Vector3(0, -0.0, 0.2), linear: Vector3(0.3, 0, -0.0))))
        } catch { throw RuntimeFailure(.invalidState, message: "Moving-anchor fixture could not construct a finite sample.") }
    }
    static func model(revision: UInt64 = 1) throws -> CompiledMechanicalModel {
        let baseline = try RuntimeFixtures.model(revision: revision)
        guard case .spatial(let original) = baseline.descriptor.bodies[0] else { throw RuntimeFailure(.invalidState, message: "Spatial fixture required.") }
        let ids = try [RuntimeFixtures.id(.body, "anchor-root"), RuntimeFixtures.id(.body, "moving-base"), RuntimeFixtures.id(.body, "moving-leaf")]
        let frames = try [RuntimeFixtures.id(.frame, "anchor-root-frame"), RuntimeFixtures.id(.frame, "moving-base-frame"), RuntimeFixtures.id(.frame, "moving-leaf-frame")]
        let fixed = try JointRecord(id: RuntimeFixtures.id(.joint, "base-drive"), parentBody: ids[0], childBody: ids[1],
            parentAnchor: JointAnchor(frame: frame(), placement: .prescribed),
            childAnchor: JointAnchor(frame: RuntimeFixtures.id(.frame, "base-child"), placement: .fixed(.identity)), manifold: JointManifold(.fixed))
        let hinge = try JointRecord(id: RuntimeFixtures.id(.joint, "leaf-hinge"), parentBody: ids[1], childBody: ids[2],
            parentAnchor: JointAnchor(frame: RuntimeFixtures.id(.frame, "leaf-parent"), placement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(0.5, 0, 0)))),
            childAnchor: JointAnchor(frame: secondaryFrame(), placement: .prescribed), manifold: JointManifold(.revolute(axis: .unitZ)))
        // Deliberately use reverse frame order: checkpoint persistence must preserve source order.
        let initial = try KinematicState(revision: revision, time: 0, q: [0], v: [0], acceleration: [0],
            prescribedAnchors: [sample(time: 0, secondary: true), sample(time: 0)])
        var bodies: [BodyRecord3D] = []
        for index in ids.indices {
            bodies.append(try BodyRecord3D(id: ids[index], frame: frames[index], mode: index == 0 ? .static : (index == 1 ? .prescribedKinematic : .dynamic),
                bodyToWorld: .identity, representations: BodyRepresentations(), inertia: original.inertia))
        }
        let tree = try KinematicTree(bodies: bodies.map { KinematicBody(body: $0) }, joints: [fixed, hinge], root: ids[0], rootBase: .fixed,
            worldFrame: RuntimeFixtures.id(.frame, "moving-world"), revision: revision, capacity: baseline.policy.kinematicCapacity)
        let snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: initial, policy: baseline.policy.jointPolicy)
        for index in bodies.indices {
            let old = bodies[index]
            bodies[index] = try BodyRecord3D(id: old.id, frame: old.frame, mode: old.mode, bodyToWorld: snapshot.body(old.id).motion.pose,
                representations: old.representations, inertia: old.inertia)
        }
        let descriptor = try MechanicalDescriptor(identity: "runtime-moving-anchor", revision: revision, bodies: bodies.map { .spatial($0) },
            joints: [MechanicalJoint(record: fixed, authority: .fixed), MechanicalJoint(record: hinge, authority: .dynamicState)], root: ids[0],
            rootBase: .fixed, rootAuthority: .fixed, worldFrame: tree.worldFrame, initialState: initial,
            representationRequirements: [], features: [], extensions: [])
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: baseline.policy)
    }
    static func session(model: CompiledMechanicalModel? = nil, capacity: RuntimeCapacity? = nil) throws -> RuntimeFixtures.Session {
        try RuntimeFixtures.session(model: model ?? self.model(), configuration: RuntimeFixtures.configuration(capacity: capacity))
    }
    static func advance(_ session: any RuntimeSessionOperating) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            let count = try CounterRuntimeContributors.count(trial.contributor("integrator-counter")), random = try trial.nextRandom()
            let time = trial.timeSeconds + 0.25
            let first = try sample(time: time), second = try sample(time: time, secondary: true)
            _ = try trial.prescribedAnchor(first.frame)
            try trial.setPrescribedAnchor(first); try trial.setTime(time); try trial.setPrescribedAnchor(second)
            try trial.setPosition(trial.position(at: 0) + Double((random & 15) + 1) / 16, at: 0)
            try trial.setVelocity(Double(count + 1), at: 0); try trial.setAcceleration(0.75, at: 0)
            try trial.replaceContributor(CounterRuntimeContributors.record(count + 1))
            return .accept
        }
    }
    static func bits(_ state: KinematicState) -> [UInt64] {
        var values = [state.time] + state.q + state.v + state.acceleration
        for sample in state.prescribedAnchors {
            let r = sample.motion.pose.rotation
            values += [sample.time, r.w, r.x, r.y, r.z]
            for vector in [sample.motion.pose.translation, sample.motion.velocity.angular, sample.motion.velocity.linear,
                           sample.motion.acceleration.angular, sample.motion.acceleration.linear] { values += [vector.x, vector.y, vector.z] }
        }
        return values.map { $0.bitPattern }
    }
    static func checkpoint(_ source: RuntimeCheckpoint, anchors: [PrescribedAnchorState]) throws -> RuntimeCheckpoint {
        try RuntimeCheckpoint(model: source.model, continuation: source.continuation,
            physical: KinematicState(revision: source.physical.revision, time: source.physical.time, q: source.physical.q, v: source.physical.v,
                acceleration: source.physical.acceleration, prescribedAnchors: anchors), contributors: source.contributors,
            random: source.random, acceptedSteps: source.acceptedSteps)
    }
    static func altered(_ sample: PrescribedAnchorState, quaternion: Bool) throws(RuntimeFailure) -> PrescribedAnchorState {
        do {
            let old = sample.motion, r = old.pose.rotation
            let pose = quaternion ? RigidTransform(rotation: try UnitQuaternion(unitW: -r.w, x: -r.x, y: -r.y, z: -r.z), translation: old.pose.translation) : old.pose
            let velocity = quaternion ? old.velocity : SpatialMotion(angular: old.velocity.angular, linear: try Vector3(old.velocity.linear.x, 0.0, old.velocity.linear.z))
            return try PrescribedAnchorState(frame: sample.frame, time: sample.time, motion: FrameMotion(pose: pose, velocity: velocity, acceleration: old.acceleration))
        } catch { throw RuntimeFailure(.invalidState, message: "Bit-alteration fixture failed.") }
    }
}
