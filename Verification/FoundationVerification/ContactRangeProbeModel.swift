import SwiftMechanics

/// Genuine fixed-root sphere sources; recipes never supply an external world pose.
final class ContactRangeProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let root: EntityID
    let child: EntityID
    let firstCollider: EntityID
    let secondCollider: EntityID
    let colliders: [ObservationColliderBinding]

    @inline(never) init(trigger: Bool = false, childMass: Double = 1,
                        rootPose: RigidTransform = .identity) throws {
        root = try EntityID(kind: .body, key: "contact-range-root")
        child = try EntityID(kind: .body, key: "contact-range-child")
        firstCollider = try EntityID(kind: .collider, key: "contact-range-a")
        secondCollider = try EntityID(kind: .collider, key: "contact-range-b")
        model = try Self.compile(root: root, child: child, mass: childMass, rootPose: rootPose)
        colliders = try [Self.recipe(firstCollider, body: root, trigger: trigger),
                        Self.recipe(secondCollider, body: child, trigger: false)]
    }

    @inline(never) private static func compile(root: EntityID, child: EntityID,
                                             mass: Double, rootPose: RigidTransform) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let childPose = try rootPose.composed(with: RigidTransform(rotation: .identity, translation: Vector3(3, 0, 0)))
        let bodies: [MechanicalBody] = try [
            .spatial(body(root, frame: "contact-range-root-frame", mode: .static, mass: 1, pose: rootPose, policy: inertia)),
            .spatial(body(child, frame: "contact-range-child-frame", mode: .dynamic, mass: mass, pose: childPose, policy: inertia))]
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "contact-range-slide"), parentBody: root, childBody: child,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "contact-range-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "contact-range-child-anchor"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitX)))
        let descriptor = try MechanicalDescriptor(identity: "contact-range-public", revision: 1, bodies: bodies,
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "contact-range-world"),
            initialState: KinematicState(revision: 1, time: 0, q: [3], v: [0], acceleration: [0]),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertia, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 4096, maximumSparsityEntries: 12,
            maximumDependencyEntries: 200, maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor, policy: policy)
    }

    private static func body(_ id: EntityID, frame: String, mode: BodyMotionMode, mass: Double,
                             pose: RigidTransform, policy: InertiaValidationPolicy) throws -> BodyRecord3D {
        try BodyRecord3D(id: id, frame: EntityID(kind: .frame, key: frame), mode: mode, bodyToWorld: pose,
            representations: representations(),
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: mass, centerOfMass: .zero,
                inertiaAtCenter: .identity, policy: policy),
                provenance: SourceProvenance(source: "contact-range-public", revision: 1), quality: .exact))
    }

    private static func representations() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry: GeometryRepresentation(kind: .collisionGeometry,
            assetKey: "contact-range-unit-sphere", provenance: SourceProvenance(source: "contact-range-public", revision: 1), quality: .exact))
    }

    private static func recipe(_ id: EntityID, body: EntityID, trigger: Bool) throws -> ObservationColliderBinding {
        try ObservationColliderBinding(colliderID: id, body: body, geometryRevision: 1,
            shape: .sphere(radius: 1), margin: 0, representations: representations(), expectedSourceRevision: 1,
            resolution: .analytic, colliderToBody: .identity,
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: trigger))
    }
}
