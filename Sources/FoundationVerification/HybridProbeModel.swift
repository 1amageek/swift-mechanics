import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler
import MechanicsCollision
import MechanicsContactLaws

struct HybridProbeModel {
    @inline(never) static func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let root = try body("ground", mode: .static, mass: 1, height: 0, policy: inertiaPolicy)
        let ball = try body("ball", mode: .dynamic, mass: 2, height: 1.5, policy: inertiaPolicy)
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "hybrid-probe-slide"), parentBody: root.id, childBody: ball.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "hybrid-probe-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "hybrid-probe-child"), placement: .fixed(.identity)), manifold: JointManifold(.prismatic(axis: .unitZ)))
        let descriptor = try MechanicalDescriptor(identity: "hybrid-public-probe", revision: 1, bodies: [.spatial(root), .spatial(ball)],
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "hybrid-probe-world"), initialState: KinematicState(revision: 1, time: 0, q: [1.5], v: [0], acceleration: [-10]),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1), inertiaPolicy: inertiaPolicy,
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 30, maximumIdentifierBytes: 2000,
            maximumSparsityEntries: 100, maximumDependencyEntries: 200, maximumExtensionRecords: 1, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor, policy: policy)
    }

    @inline(never) private static func body(_ key: String, mode: BodyMotionMode, mass: Double, height: Double, policy: InertiaValidationPolicy) throws -> BodyRecord3D {
        let provenance = try SourceProvenance(source: "hybrid-public-probe", revision: 1)
        return try BodyRecord3D(id: EntityID(kind: .body, key: "hybrid-probe-" + key), frame: EntityID(kind: .frame, key: "hybrid-probe-" + key + "-frame"),
            mode: mode, bodyToWorld: RigidTransform(rotation: .identity, translation: Vector3(0, 0, height)), representations: representations(),
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: .identity, policy: policy), provenance: provenance, quality: .exact))
    }

    @inline(never) static func representations() throws -> BodyRepresentations {
        try BodyRepresentations(collisionGeometry: GeometryRepresentation(kind: .collisionGeometry, assetKey: "hybrid-analytic",
            provenance: SourceProvenance(source: "hybrid-public-probe", revision: 1), quality: .exact))
    }

    @inline(never) static func proxy(_ key: String, body: EntityID, shape: CollisionShape, pose: RigidTransform, frame: EntityID) throws -> CollisionProxy {
        try CollisionProxy(colliderID: EntityID(kind: .collider, key: "hybrid-probe-" + key), bodyID: body, frameID: frame, geometryRevision: 1, frameRevision: 1,
            shape: shape, margin: 0, representations: representations(), expectedSourceRevision: 1, resolution: .analytic, pose: pose,
            filter: ColliderFilter(enabled: true, layerBits: 1, maskBits: 1, isTrigger: false))
    }

    @inline(never) static func contactLaw() throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: "hybrid-probe-" + key), revision: 1), youngModulus: 1e6, poissonsRatio: 0.2,
                linearStiffness: 2000, normalDamping: 0, huntCrossleyAlpha: 0, friction: .none,
                resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
        }
        var work = ContactWork(budget: try ContactBudget(operations: 1000, scalarStorage: 128, records: 4))
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("sphere"), second: material("plane"), selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100),
            lossPolicy: .separateImpact(restitution: 0.5, thresholdSpeed: 0), resistanceRadius: 0.5, override: nil, work: &work)
    }
}
