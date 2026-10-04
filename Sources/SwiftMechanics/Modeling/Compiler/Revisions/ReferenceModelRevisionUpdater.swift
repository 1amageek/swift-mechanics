
public struct ReferenceModelRevisionUpdater: ModelRevisionUpdating, Sendable {
    public init() {}

    public func transition(from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                           policy: StateMigrationPolicy) throws(CompilationFailure) -> ModelTransition {
        guard source.stamp.identity == target.stamp.identity else {
            throw .one(.wrongModel, .migration, message: "Updates require the same model identity.")
        }
        guard target.stamp.revision > source.stamp.revision else {
            throw .one(.staleRevision, .migration, message: "Updates require a strictly newer revision.")
        }
        let old = source.descriptor, new = target.descriptor
        var changes: [ParameterReference] = []
        func changed(_ entity: EntityID?, _ aspect: ParameterAspect) {
            let value = ParameterReference(entity: entity, aspect: aspect)
            if !changes.contains(value) { changes.append(value) }
        }
        var topology = source.tree.layout != target.tree.layout
            || old.root != new.root || old.worldFrame != new.worldFrame || old.rootBase != new.rootBase
            || old.bodies.count != new.bodies.count || old.joints.count != new.joints.count
            || old.extensions.count != new.extensions.count
        var compatible = !topology && old.rootAuthority == new.rootAuthority
        if old.rootAuthority != new.rootAuthority { changed(nil, .coordinateAuthority) }
        if old.initialState.time != new.initialState.time || old.initialState.q != new.initialState.q
            || old.initialState.v != new.initialState.v || old.initialState.acceleration != new.initialState.acceleration
            || old.initialState.prescribedAnchors != new.initialState.prescribedAnchors { changed(nil, .initialConfiguration) }
        let oldBodies = Dictionary(uniqueKeysWithValues: old.bodies.map { ($0.id, $0) })
        for body in new.bodies {
            guard let previous = oldBodies[body.id] else { topology = true; compatible = false; continue }
            if previous.frame != body.frame || previous.dimension != body.dimension { topology = true; compatible = false }
            if previous.mode != body.mode { changed(body.id, .bodyMode); compatible = false }
            let oldPose: RigidTransform, newPose: RigidTransform
            do { oldPose = try previous.kinematicBody().referencePose; newPose = try body.kinematicBody().referencePose }
            catch { throw .one(.producerValidationFailure, .migration, records: [body.id], message: "Admitted body pose could not be reconstructed.") }
            if !samePose(oldPose, newPose) {
                changed(body.id, body.id == new.root ? .rootPlacement : .bodyPlacement)
                if body.id == new.root { compatible = false }
            }
            if previous.representations.geometricShape != body.representations.geometricShape { changed(body.id, .geometricShape) }
            if previous.representations.displayGeometry != body.representations.displayGeometry { changed(body.id, .displayGeometry) }
            if previous.representations.collisionGeometry != body.representations.collisionGeometry { changed(body.id, .collisionGeometry) }
            switch (previous, body) {
            case (.planar(let left), .planar(let right)): if left.inertia != right.inertia { changed(body.id, .inertia) }
            case (.spatial(let left), .spatial(let right)): if left.inertia != right.inertia { changed(body.id, .inertia) }
            default: topology = true; compatible = false
            }
        }
        let oldJoints = Dictionary(uniqueKeysWithValues: old.joints.map { ($0.record.id, $0) })
        for joint in new.joints {
            guard let previous = oldJoints[joint.record.id] else { topology = true; compatible = false; continue }
            let left = previous.record, right = joint.record
            if left.parentBody != right.parentBody || left.childBody != right.childBody
                || left.parentAnchor.frame != right.parentAnchor.frame || left.childAnchor.frame != right.childAnchor.frame
                || left.manifold.positionCount != right.manifold.positionCount || left.manifold.velocityCount != right.manifold.velocityCount {
                topology = true; compatible = false
            }
            if previous.authority != joint.authority { changed(right.id, .coordinateAuthority); compatible = false }
            if left.manifold != right.manifold { changed(right.id, .jointManifold); compatible = false }
            if left.parentAnchor.placement != right.parentAnchor.placement || left.childAnchor.placement != right.childAnchor.placement {
                changed(right.id, .jointAnchors); compatible = false
            }
        }
        let oldExtensions = Dictionary(uniqueKeysWithValues: old.extensions.map { ($0.id, $0) })
        for record in new.extensions {
            guard let previous = oldExtensions[record.id] else { topology = true; compatible = false; continue }
            if previous.schema != record.schema || previous.references != record.references { topology = true; compatible = false }
            if previous.parameters != record.parameters { changed(record.id, .extensionParameters) }
        }
        if old.features != new.features || old.representationRequirements != new.representationRequirements
            || source.validatorRegistrations != target.validatorRegistrations || source.policy != target.policy {
            changed(nil, .featureRequirements)
        }
        if topology { changed(nil, .topology); compatible = false }
        guard policy != .preserveIfKinematicsUnchanged || compatible else {
            throw .one(.incompatibleMigration, .migration, message: "Preservation requires identical coordinate meaning, authority, body modes and kinematic geometry.")
        }
        let changedSet = Set(changes)
        var invalidated: [CompiledCacheKey] = [], seen: Set<CompiledCacheKey> = []
        for dependency in source.cacheDependencies + target.cacheDependencies {
            if (topology || dependency.inputs.contains(where: { changedSet.contains($0) })) && seen.insert(dependency.cache).inserted {
                invalidated.append(dependency.cache)
            }
        }
        return ModelTransition(source: source.stamp, model: target,
            kind: topology ? .topology : (changes.isEmpty ? .revisionOnly : .parameters),
            changedParameters: changes, invalidatedCaches: invalidated, policy: policy,
            compatibility: compatible ? .preservesCoordinates : .requiresReset)
    }

    public func migrate(_ state: CompiledKinematicState, using transition: ModelTransition,
                        to target: CompiledMechanicalModel) throws(CompilationFailure) -> CompiledKinematicState {
        guard state.stamp.identity == transition.source.identity else { throw .one(.wrongModel, .migration, message: "Source state belongs to another model.") }
        guard state.stamp == transition.source else { throw .one(.staleRevision, .migration, message: "Source state does not match transition revision.") }
        guard target.stamp == transition.target, target.descriptor == transition.targetDescriptor,
              target.policy == transition.targetPolicy, target.validatorRegistrations == transition.targetRegistrations else {
            throw .one(.mismatchedTransition, .migration, message: "Target snapshot differs from the admitted transition.")
        }
        guard transition.policy == .preserveIfKinematicsUnchanged, transition.compatibility == .preservesCoordinates else {
            throw .one(.resetRequired, .migration, message: "Reset policy requires explicit construction from target initial state.")
        }
        let migrated: KinematicState
        do {
            migrated = try KinematicState(revision: target.stamp.revision, time: state.state.time, q: state.state.q,
                v: state.state.v, acceleration: state.state.acceleration, prescribedAnchors: state.state.prescribedAnchors)
        } catch { throw .one(.invalidCoordinates, .migration, message: "Preserved state construction failed.") }
        return try target.makeState(migrated)
    }

    // Exact geometric identity avoids changing coordinate meaning under a guessed migration tolerance.
    private func samePose(_ left: RigidTransform, _ right: RigidTransform) -> Bool {
        left.translation == right.translation && (left.rotation == right.rotation || left.rotation == right.rotation.negated())
    }
}
