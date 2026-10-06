import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyContactRangeObservations() throws {
        try contactRangeSphere()
        try contactRangeMountCovariance()
        try contactRangeTriggerCycle()
        try contactRangeTactilePower()
        try contactRangeSourceRefusal()
        try contactRangePoseRefusal()
        print("Contact/range observations passed: original sphere range, transformed mount, trigger cycle, current tactile power/history and source refusal.")
    }

    @inline(never) private static func contactRangeSphere() throws {
        let context = try ContactRangeProbeContext()
        let scene = try context.scene(position: 3, time: 0)
        let ray = try CollisionRay(origin: .zero, direction: .unitX, maximumDistance: 10)
        let result = try context.range(scene: scene, ray: ray)
        try require(result.hits.count == 1)
        let hit = result.hits[0]
        try require(hit.geometry.colliderID == context.physical.secondCollider)
        try require(hit.geometry.bodyID == context.physical.child)
        try require(abs(hit.distance - 2) < 1e-11)
        try contactRangeVector(hit.point, 2, 0, 0)
        try contactRangeVector(hit.outwardNormal, -1, 0, 0)
        try require(result.timeSeconds == 0 && result.expressedFrame == context.physical.model.tree.worldFrame)
        try require(result.distanceUnit == .length)
    }

    @inline(never) private static func contactRangeMountCovariance() throws {
        // World root Rz(90 degrees), sensor Rz(-90 degrees) and a nonzero mounted origin.
        // The local ray begins at (-.25,0,0), so its world origin remains (1,2,0).
        let root = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: Vector3(1, 2, 0))
        let sensor = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: -.pi / 2), translation: Vector3(0, -0.25, 0))
        let context = try ContactRangeProbeContext(rootPose: root, sensorPose: sensor)
        let scene = try context.scene(position: 3, time: 0)
        let ray = try CollisionRay(origin: Vector3(-0.25, 0, 0), direction: .unitY, maximumDistance: 10)
        let result = try context.range(scene: scene, ray: ray)
        try require(result.hits.count == 1)
        try require(abs(result.hits[0].distance - 2) < 1e-11)
        try contactRangeVector(result.ray.origin, 1, 2, 0)
        try contactRangeVector(result.ray.direction, 0, 1, 0)
        try contactRangeVector(result.hits[0].point, 1, 4, 0)
        try contactRangeVector(result.hits[0].outwardNormal, 0, -1, 0)
    }

    @inline(never) private static func contactRangeTriggerCycle() throws {
        let context = try ContactRangeProbeContext(trigger: true)
        let outside = try context.trigger(scene: context.scene(position: 3, time: 0), previous: nil, index: 0)
        try require(outside.update.state.intersections.isEmpty && outside.update.events.isEmpty)
        let inside = try context.trigger(scene: context.scene(position: 1.5, time: 1), previous: outside, index: 1)
        try require(inside.update.events.count == 1 && inside.witnesses.count == 1)
        try require(inside.update.events[0].phase == .entered && inside.update.events[0].sampleIndex == 1)
        try require(abs(inside.witnesses[0].separation + 0.5) < 1e-11)
        let departed = try context.trigger(scene: context.scene(position: 3, time: 2), previous: inside, index: 2)
        try require(departed.update.state.intersections.isEmpty && departed.update.events.count == 1)
        try require(departed.update.events[0].phase == .exited && departed.update.events[0].sampleIndex == 2)
        try require(departed.update.events[0].pair == inside.update.events[0].pair)
        try require(departed.exitedWitnesses.count == 1)
        try require(departed.exitedWitnesses[0].pair == inside.witnesses[0].pair)
        try require(departed.exitedWitnesses[0].pointA == inside.witnesses[0].pointA)
        try require(departed.exitedWitnesses[0].pointB == inside.witnesses[0].pointB)
        try require(departed.exitedWitnesses[0].separation == inside.witnesses[0].separation)
        try require(inside.sampleIndex == 1 && inside.timeSeconds == 1)
    }

    @inline(never) private static func contactRangeTactilePower() throws {
        let sensor = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: Vector3(0, 0.25, 0))
        let context = try ContactRangeProbeContext(sensorPose: sensor)
        let scene = try context.scene(position: 1.8, velocity: -2, time: 5)
        let binding = try context.binding(time: 5)
        let first = try context.tactile(scene: scene, mount: context.mount, binding: binding)
        try require(first.side == .first && first.expressedFrame == context.mount.sensorFrame)
        // k=1000, delta=.2, vn=-2: Fn=200, U=20, pair power=-400, Udot=400.
        try contactRangeVector(first.witness.pointA, 1, 0, 0)
        try contactRangeVector(first.witness.pointB, 0.8, 0, 0)
        try contactRangeVector(first.witness.normal, 1, 0, 0)
        try require(abs(first.witness.separation + 0.2) < 1e-11)
        try require(first.witness.pair.first.colliderID == context.physical.firstCollider)
        try require(first.witness.pair.second.colliderID == context.physical.secondCollider)
        try contactRangeVector(first.applicationPoint, 0.9, 0, 0)
        try contactRangeVector(first.relativeVelocity, -2, 0, 0)
        try contactRangeVector(first.relativeAngularVelocity, 0, 0, 0)
        try contactRangeVector(first.force, 0, 200, 0)
        try contactRangeVector(first.couple, 0, 0, -50)
        try require(abs(first.response.compressiveNormalForce - 200) < 1e-9)
        try require(abs(first.response.normalStoredEnergy - 20) < 1e-9)
        try require(abs(first.response.relativeMechanicalPower + 400) < 1e-9)
        try require(abs(first.response.elasticPotentialRatePower - 400) < 1e-9)
        try require(first.response.normalDissipationPower == 0 && first.response.resistanceDissipationPower == 0)
        try require(first.response.acceptedHistory == binding.accepted && first.timeSeconds == 5)
        try require(first.temporalMeaning == .instantaneousContinuous && first.forceUnit == .force)
        try contactRangeOtherSide(context, scene: scene, binding: binding, first: first)
        try contactRangeRepeatHistory(context, scene: scene, binding: binding)
    }

    @inline(never) private static func contactRangeOtherSide(_ context: ContactRangeProbeContext,
        scene: ContactRangeScene, binding: TactileContactBinding, first: TactileObservation) throws {
        let mount = try ContactRangeProbeContext.mount(body: context.physical.child, pose: .identity, suffix: "child")
        let second = try context.tactile(scene: scene, mount: mount, binding: binding)
        try require(second.side == .second)
        try contactRangeVector(second.force, 200, 0, 0)
        try contactRangeVector(second.couple, 0, 0, 0)
        let firstWorld = try first.mountedMotion.sensorToWorld.rotation.rotating(first.force)
        let secondWorld = try second.mountedMotion.sensorToWorld.rotation.rotating(second.force)
        try contactRangeVector(firstWorld.adding(secondWorld), 0, 0, 0)
        // Shift both sensor couples to world origin; the contact produces zero net moment.
        let firstMoment = try first.mountedMotion.sensorToWorld.rotation.rotating(first.couple)
            .adding(first.mountedMotion.sensorToWorld.translation.cross(firstWorld))
        let secondMoment = try second.mountedMotion.sensorToWorld.rotation.rotating(second.couple)
            .adding(second.mountedMotion.sensorToWorld.translation.cross(secondWorld))
        try contactRangeVector(firstMoment.adding(secondMoment), 0, 0, 0)
        try require(second.response.acceptedHistory == binding.accepted)
    }

    @inline(never) private static func contactRangeRepeatHistory(_ context: ContactRangeProbeContext,
        scene: ContactRangeScene, binding: TactileContactBinding) throws {
        let repeated = try context.tactile(scene: scene, mount: context.mount, binding: binding)
        try require(repeated.response.acceptedHistory == binding.accepted && repeated.timeSeconds == binding.accepted.timeSeconds)
    }

    @inline(never) private static func contactRangeSourceRefusal() throws {
        let original = try ContactRangeProbeContext(trigger: true)
        let previous = try original.trigger(scene: original.scene(position: 3, time: 0), previous: nil, index: 0)
        let changed = try ContactRangeProbeContext(trigger: true, childMass: 2)
        let scene = try changed.scene(position: 1.5, time: 1)
        try require(original.physical.model.stamp == changed.physical.model.stamp)
        try require(original.physical.model.descriptor != changed.physical.model.descriptor)
        try contactRangeRejectPrevious(changed, scene: scene, previous: previous)
        try require(previous.sampleIndex == 0 && previous.update.state.intersections.isEmpty && previous.update.events.isEmpty)
    }

    @inline(never) private static func contactRangeRejectPrevious(_ context: ContactRangeProbeContext,
        scene: ContactRangeScene, previous: TriggerObservation) throws {
        var work = try ContactRangeProbeContext.numericalWork(), collision = try ContactRangeProbeContext.collisionWork()
        let filters = CollisionFilterPolicy(jointExclusions: [], allowSameBody: false, user: nil)
        do throws(ContactRangeObservationError) {
            _ = try context.observer.triggers(scene: scene, mount: context.mount, filters: filters,
                previous: previous, sampleIndex: 1, policy: context.policy, collisionWork: &collision, work: &work)
        } catch {
            guard case .staleSource = error else { throw error }
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    @inline(never) private static func contactRangePoseRefusal() throws {
        let shifted = try RigidTransform(rotation: .identity, translation: Vector3(0.5, 0, 0))
        let foreign = try ContactRangeProbeContext(rootPose: shifted)
        let foreignScene = try foreign.scene(position: 3, time: 0)
        let observer: any ContactRangeObserving = ReferenceContactRangeObserver(
            kinematics: ContactRangeForeignMotion(source: foreignScene.source))
        let original = try ContactRangeProbeContext(observer: observer)
        let scene = try original.scene(position: 3, time: 0)
        try require(original.physical.model.stamp == foreign.physical.model.stamp)
        try require(original.physical.model.descriptor != foreign.physical.model.descriptor)
        try contactRangeRejectPose(original, scene: scene)
    }

    @inline(never) private static func contactRangeRejectPose(_ context: ContactRangeProbeContext, scene: ContactRangeScene) throws {
        var work = try ContactRangeProbeContext.numericalWork(), collision = try ContactRangeProbeContext.collisionWork()
        let ray = try CollisionRay(origin: .zero, direction: .unitX, maximumDistance: 10)
        do throws(ContactRangeObservationError) {
            _ = try context.observer.range(scene: scene, mount: context.mount, ray: ray,
                targets: [context.physical.secondCollider], policy: context.policy, collisionWork: &collision, work: &work)
        } catch {
            guard case .invalidSupplierEvidence = error else { throw error }
            return
        }
        throw FoundationVerificationError.analyticCheckFailed
    }

    private static func contactRangeVector(_ value: Vector3, _ x: Double, _ y: Double, _ z: Double) throws {
        try require(abs(value.x - x) < 1e-9 && abs(value.y - y) < 1e-9 && abs(value.z - z) < 1e-9)
    }
}

/// Returns genuinely issued original mounted motion at a different complete compiled source.
private struct ContactRangeForeignMotion: KinematicObserving {
    let source: ObservationSource
    @inline(never) func motion(source: ObservationSource, mount: ObservationMount, policy: ObservationPolicy,
                               work: inout NumericalWork) throws(ObservationError) -> MountedMotionObservation {
        let service: any KinematicObserving = ReferenceKinematicObserver()
        return try service.motion(source: self.source, mount: mount, policy: policy, work: &work)
    }
    func encoder(source: ObservationSource, joint: EntityID, policy: ObservationPolicy,
                 work: inout NumericalWork) throws(ObservationError) -> JointEncoderObservation {
        let service: any KinematicObserving = ReferenceKinematicObserver()
        return try service.encoder(source: source, joint: joint, policy: policy, work: &work)
    }
}
