extension MachineDefinitionContext {
    internal mutating func lowerStructuralBody<Content: Machine>(
        _ declaration: RigidBody<Content>
    ) throws(MachineDefinitionFailure) {
        guard structuralEnabled else {
            throw .compilation(.one(.unsupportedCapability, .input, records: [declaration.id],
                message: "RigidBody requires StructuralMachineDefinition and explicit chart initialization."))
        }
        let pose: RigidTransform
        switch declaration.placement {
        case .world(let bodyToWorld):
            guard structuralBody == nil, structuralChildToWorld == nil else {
                throw .compilation(.one(.invalidInput, .topology, records: [declaration.id],
                    message: "A nested physical body needs an explicit joint and connected placement."))
            }
            do { pose = try structuralPlacement.composed(with: bodyToWorld) }
            catch {
                throw .compilation(.one(.invalidInput, .input, records: [declaration.id],
                    message: "Root spatial placement failed composition."))
            }
        case .connected:
            guard let supplied = structuralChildToWorld, structuralChildCount == 0 else {
                throw .compilation(.one(.invalidInput, .topology, records: [declaration.id],
                    message: "A connected body requires one unfilled nested joint endpoint."))
            }
            pose = supplied
        }
        let record: BodyRecord3D
        do {
            record = try BodyRecord3D(id: declaration.id, frame: declaration.frame,
                mode: declaration.mode, bodyToWorld: pose,
                representations: declaration.representations, inertia: declaration.inertia)
        } catch { throw .invalidBody(error) }
        let absolute = try resolve(.local(declaration.id))
        try append(.spatial(record))
        structuralRegisteredBodyCount += 1
        if structuralChildToWorld != nil {
            structuralChild = absolute; structuralChildCount = 1
        }

        let oldBody = structuralBody, oldPose = structuralBodyToWorld
        let oldPlacement = structuralPlacement, oldChildPose = structuralChildToWorld
        let oldChild = structuralChild, oldCount = structuralChildCount
        defer {
            structuralBody = oldBody; structuralBodyToWorld = oldPose
            structuralPlacement = oldPlacement; structuralChildToWorld = oldChildPose
            structuralChild = oldChild; structuralChildCount = oldCount
        }
        structuralBody = absolute; structuralBodyToWorld = pose
        structuralPlacement = .identity; structuralChildToWorld = nil
        structuralChild = nil; structuralChildCount = 0
        try lower(declaration.content)
    }

    internal mutating func lowerStructuralJoint<Content: Machine>(
        _ configuration: StructuralJointConfiguration, content: Content
    ) throws(MachineDefinitionFailure) {
        guard structuralEnabled, let policy = structuralJointPolicy,
              let parent = structuralBody, let parentToWorld = structuralBodyToWorld,
              structuralChildToWorld == nil else {
            throw .compilation(.one(.invalidInput, .topology, records: [configuration.id],
                message: "A nested joint requires an enclosing physical body."))
        }
        let parentAnchorToBody: RigidTransform, childToWorld: RigidTransform
        do {
            parentAnchorToBody = try structuralPlacement.composed(with: configuration.parentAnchorToBody)
            let motion = try JointMotionEvaluator().evaluate(configuration.manifold,
                q: configuration.initial.coordinates.q[...], v: configuration.initial.coordinates.v[...],
                acceleration: configuration.initial.acceleration[...], policy: policy)
            childToWorld = try parentToWorld.composed(with: parentAnchorToBody)
                .composed(with: motion.frameMotion.pose)
                .composed(with: configuration.childAnchorToBody.inverted())
        } catch {
            throw .compilation(.one(.invalidCoordinates, .coordinates, records: [configuration.id],
                message: "Actual joint chart or two-anchor initial placement failed evaluation."))
        }
        let admitted = try reserveStructuralJoint(id: configuration.id, parentFrame: configuration.parentFrame,
            childFrame: configuration.childFrame, parent: parent)
        let id = admitted.id
        let oldPlacement = structuralPlacement, oldChildPose = structuralChildToWorld
        let oldChild = structuralChild, oldCount = structuralChildCount
        defer {
            structuralPlacement = oldPlacement; structuralChildToWorld = oldChildPose
            structuralChild = oldChild; structuralChildCount = oldCount
        }
        structuralPlacement = .identity; structuralChildToWorld = childToWorld
        structuralChild = nil; structuralChildCount = 0
        try lower(content)
        guard structuralChildCount == 1, let child = structuralChild else {
            throw .compilation(.one(.invalidInput, .topology, records: [id],
                message: "A selected nested joint branch must produce exactly one direct physical endpoint."))
        }
        let record: JointRecord
        do {
            record = try JointRecord(id: id, parentBody: parent, childBody: child,
                parentAnchor: JointAnchor(frame: admitted.parentFrame, placement: .fixed(parentAnchorToBody)),
                childAnchor: JointAnchor(frame: admitted.childFrame, placement: .fixed(configuration.childAnchorToBody)),
                manifold: configuration.manifold)
        } catch { throw .invalidJoint(error) }
        try finishStructuralJoint(MechanicalJoint(record: record, authority: configuration.authority))
        structuralCoordinates[id] = configuration.initial.coordinates
        structuralAccelerations[id] = configuration.initial.acceleration
    }
}
