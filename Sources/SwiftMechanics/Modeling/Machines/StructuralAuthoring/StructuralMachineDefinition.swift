public struct StructuralMachineDefinition<Content: Machine>: StructuralMachineDefining, StructuralPhysicsDraftProviding {
    public let identity: String
    public let revision: UInt64
    public let time: Double
    public let root: EntityID
    public let rootBase: BaseLayout
    public let rootAuthority: CoordinateAuthority
    public let worldFrame: EntityID
    public let baseCoordinates: BaseCoordinates
    public let baseAcceleration: [Double]
    public let content: Content

    public init(identity: String, revision: UInt64, time: Double, root: EntityID,
                rootBase: BaseLayout, rootAuthority: CoordinateAuthority, worldFrame: EntityID,
                baseCoordinates: BaseCoordinates, baseAcceleration: [Double],
                @MachineBuilder content: () -> Content) {
        self.identity = identity; self.revision = revision; self.time = time
        self.root = root; self.rootBase = rootBase; self.rootAuthority = rootAuthority
        self.worldFrame = worldFrame; self.baseCoordinates = baseCoordinates
        self.baseAcceleration = baseAcceleration; self.content = content()
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This source-only facade lowers selected spatial
    // nested records. Deferred forward bindings, rigid constituent aggregation, general
    // relationships and original Native/WASM/Embedded behavior remain unqualified.
    public func makeDescriptor(definitionPolicy: MachineDefinitionPolicy,
                               compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> MechanicalDescriptor {
        let context = try lowerStructuralDraft(definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy)
        // FIXME(INCOMPLETE_IMPLEMENTATION): The original descriptor has no executable gear,
        // passive-law or motor provider registry. Model-only calls reject these declarations;
        // use makePhysicsDraft and the actual structural-system compiler instead.
        guard context.structuralGearDrafts.isEmpty, context.structuralPassiveDrafts.isEmpty,
              context.structuralMotorDrafts.isEmpty else {
            throw .compilation(.one(.unsupportedCapability, .input,
                message: "Physical declarations require executable structural-system compilation."))
        }
        return try descriptor(from: context, compilationPolicy: compilationPolicy)
    }

    public func makePhysicsDraft(definitionPolicy: MachineDefinitionPolicy,
        compilationPolicy: CompilationPolicy
    ) throws(MachineDefinitionFailure) -> StructuralPhysicsDraft {
        let context = try lowerStructuralDraft(definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy)
        return StructuralPhysicsDraft(descriptor: try descriptor(from: context, compilationPolicy: compilationPolicy),
            gears: context.structuralGearDrafts.map {
                StructuralGearRelation(id: $0.id, rowID: $0.rowID, first: $0.first, second: $0.second,
                    firstTeeth: $0.firstTeeth, secondTeeth: $0.secondTeeth,
                    phaseRadians: $0.phase, phaseScaleRadians: $0.phaseScale, internalMesh: $0.internalMesh)
            }, passiveLaws: context.structuralPassiveDrafts.map {
                StructuralPassiveLaw(id: $0.id, termID: $0.termID, joint: $0.joint, law: $0.law)
            }, torques: context.structuralMotorDrafts.map {
                StructuralConstantTorque(id: $0.id, joint: $0.joint, torqueNm: $0.torqueNm)
            })
    }

    private func lowerStructuralDraft(definitionPolicy: MachineDefinitionPolicy,
        compilationPolicy: CompilationPolicy
    ) throws(MachineDefinitionFailure) -> MachineDefinitionContext {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar-floating base input reaches this branch.
        // This facade is spatial; a qualified planar structural surface is required to admit it.
        guard rootBase != .planarFloating else {
            throw .compilation(.one(.unsupportedCapability, .input, records: [root],
                message: "StructuralMachineDefinition admits fixed or spatial-floating roots only."))
        }
        guard baseCoordinates.q.count == rootBase.positionCount,
              baseCoordinates.v.count == rootBase.velocityCount,
              baseAcceleration.count == rootBase.velocityCount,
              time.isFinite, baseAcceleration.allSatisfy({ $0.isFinite }) else {
            throw .invalidJoint(.invalidCoordinateCount)
        }
        guard (rootBase == .fixed) == (rootAuthority == .fixed) else {
            throw .compilation(.one(.incompatibleCoordinateAuthority, .modes, records: [root],
                message: "Structural base chart and authority disagree."))
        }
        if rootBase == .spatialFloating {
            do {
                _ = try JointMotionEvaluator().evaluate(JointManifold(.sixDOF), q: baseCoordinates.q[...],
                    v: baseCoordinates.v[...], acceleration: baseAcceleration[...], policy: compilationPolicy.jointPolicy)
            } catch {
                throw .compilation(.one(.invalidCoordinates, .coordinates, records: [root],
                    message: "Actual spatial-floating base chart failed evaluation."))
            }
        }
        var context = MachineDefinitionContext(policy: definitionPolicy)
        context.structuralEnabled = true; context.structuralJointPolicy = compilationPolicy.jointPolicy
        try context.reserveWorld(worldFrame)
        try context.lower(content)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Mixed structural and legacy record declarations
        // reach this guard. Explicit initial-state ownership for mixed records is not supplied;
        // source-only structural drafts reject these records rather than inventing coordinates.
        guard context.structuralRegisteredBodyCount == context.bodies.count,
              context.structuralCoordinates.count == context.joints.count,
              context.structuralAccelerations.count == context.joints.count,
              context.structuralPendingJoints.isEmpty else {
            throw .compilation(.one(.unsupportedCapability, .input,
                message: "Structural and legacy MachineBody/MachineJoint drafts cannot be mixed."))
        }
        return context
    }

    private func descriptor(from context: MachineDefinitionContext,
        compilationPolicy: CompilationPolicy
    ) throws(MachineDefinitionFailure) -> MechanicalDescriptor {
        let tree: KinematicTree
        do {
            let orderedBodies = context.bodies.sorted { $0.id.key < $1.id.key }
            let orderedJoints = context.joints.sorted { $0.record.id.key < $1.record.id.key }
            tree = try KinematicTree(bodies: orderedBodies.map { try $0.kinematicBody() },
                joints: orderedJoints.map { $0.record }, root: root, rootBase: rootBase,
                worldFrame: worldFrame, revision: revision, capacity: compilationPolicy.kinematicCapacity)
        } catch {
            throw .compilation(.one(.producerValidationFailure, .topology, records: [root],
                message: "Structural initial-state layout failed actual supplier tree admission."))
        }
        var q = baseCoordinates.q, v = baseCoordinates.v, acceleration = baseAcceleration
        q.reserveCapacity(tree.layout.positionCount); v.reserveCapacity(tree.layout.velocityCount)
        acceleration.reserveCapacity(tree.layout.velocityCount)
        for joint in tree.joints {
            guard let coordinates = context.structuralCoordinates[joint.id],
                  let second = context.structuralAccelerations[joint.id] else {
                throw .compilation(.one(.invalidCoordinates, .coordinates, records: [joint.id],
                    message: "Admitted structural joint has no owned initial chart sample."))
            }
            q.append(contentsOf: coordinates.q); v.append(contentsOf: coordinates.v)
            acceleration.append(contentsOf: second)
        }
        let initialState: KinematicState
        do { initialState = try KinematicState(revision: revision, time: time, q: q, v: v, acceleration: acceleration) }
        catch { throw .invalidJoint(error) }
        do {
            return try MechanicalDescriptor(identity: identity, revision: revision, bodies: context.bodies,
                joints: context.joints, root: root, rootBase: rootBase, rootAuthority: rootAuthority,
                worldFrame: worldFrame, initialState: initialState,
                representationRequirements: [], features: [], extensions: [])
        } catch { throw .compilation(error) }
    }

    public func compile(definitionPolicy: MachineDefinitionPolicy,
                        compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> CompiledMechanicalModel {
        try compile(using: ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()),
                    definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy)
    }

    public func compile<Compiler: MechanicalModelCompiling>(using compiler: Compiler,
        definitionPolicy: MachineDefinitionPolicy, compilationPolicy: CompilationPolicy
    ) throws(MachineDefinitionFailure) -> CompiledMechanicalModel {
        let descriptor = try makeDescriptor(definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy)
        do { return try compiler.compile(descriptor, policy: compilationPolicy) }
        catch { throw .compilation(error) }
    }
}
