import SwiftMechanics

enum PlanarPhysicalProbeModel {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID {
        try EntityID(kind: kind, key: "planar-physical-" + key)
    }

    @inline(never)
    static func freeBody() throws -> CompiledMechanicalModel {
        let properties = try MassProperties2D(mass: 2, centerX: 0.5, centerY: 0.25, polarInertiaAtCenter: 1)
        let body = try record("free", properties: properties, mode: .dynamic,
            pose: PlanarPose(x: 1, y: 0.7, angle: 0.3))
        return try compile(bodies: [body], joints: [], root: "free", base: .planarFloating,
            state: KinematicState(revision: 1, time: 0, q: [1, 0.7, 0.3], v: [0.4, -0.1, 0.6], acceleration: [9, 8, 7]))
    }

    @inline(never)
    static func sliders() throws -> CompiledMechanicalModel {
        let ground = try record("ground", properties: MassProperties2D(mass: 1, centerX: 0, centerY: 0, polarInertiaAtCenter: 1), mode: .static)
        let first = try record("first", properties: MassProperties2D(mass: 2, centerX: 0, centerY: 0, polarInertiaAtCenter: 1), mode: .dynamic)
        let second = try record("second", properties: MassProperties2D(mass: 3, centerX: 0, centerY: 0, polarInertiaAtCenter: 1), mode: .dynamic,
            pose: PlanarPose(x: 2, y: 0, angle: 0))
        let joints = try [slider("a", child: "first"), slider("b", child: "second")]
        return try compile(bodies: [ground, first, second], joints: joints, root: "ground", base: .fixed,
            state: KinematicState(revision: 1, time: 0, q: [0, 2], v: [0.3, 0.3], acceleration: [0, 0]))
    }

    private static func record(_ key: String, properties: MassProperties2D, mode: BodyMotionMode,
                               pose: PlanarPose? = nil) throws -> MechanicalBody {
        .planar(try BodyRecord2D(id: id(.body, key), frame: id(.frame, key), mode: mode,
            bodyToWorld: pose ?? PlanarPose(x: 0, y: 0, angle: 0),
            representations: BodyRepresentations(), inertia: InertialRepresentation2D(properties: properties,
                provenance: SourceProvenance(source: "original-planar-public", revision: 1), quality: .exact)))
    }

    private static func slider(_ key: String, child: String) throws -> MechanicalJoint {
        let joint = try JointRecord(id: id(.joint, key), parentBody: id(.body, "ground"), childBody: id(.body, child),
            parentAnchor: JointAnchor(frame: id(.frame, key + "-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame, key + "-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitX)))
        return MechanicalJoint(record: joint, authority: .dynamicState)
    }

    @inline(never)
    private static func compile(bodies: [MechanicalBody], joints: [MechanicalJoint], root: String,
                                base: BaseLayout, state: KinematicState) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let descriptor = try MechanicalDescriptor(identity: "planar-physical-" + root, revision: 1,
            bodies: bodies, joints: joints, root: id(.body, root), rootBase: base,
            rootAuthority: base == .fixed ? .fixed : .dynamicState, worldFrame: id(.frame, "world"),
            initialState: state, representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 4, maximumVelocities: 8, maximumJacobianScalars: 192),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 32,
            maximumIdentifierBytes: 8192, maximumSparsityEntries: 4096, maximumDependencyEntries: 4096,
            maximumExtensionRecords: 1, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 10000, iterations: 100),
            target: FoundationVerification.compilerVerificationTarget)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }
}
