import SwiftMechanics

/// A compiled spatial slider with a fixed, known inertia shape per kilogram.
final class ParameterIdentificationProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let root: EntityID
    let body: EntityID
    let joint: EntityID
    let positionIndex: Int
    let velocityIndex: Int

    @inline(never)
    init(identity: String = "parameter-identification-public", revision: UInt64 = 1,
        placement: RigidTransform = .identity, nominalMass: Double = 1) throws {
        let root = try EntityID(kind: .body, key: "parameter-identification-root")
        let body = try EntityID(kind: .body, key: "parameter-identification-body")
        let joint = try EntityID(kind: .joint, key: "parameter-identification-y-slider")
        let policy = try Self.compilationPolicy()
        let descriptor = try Self.descriptor(identity: identity, revision: revision, placement: placement,
            nominalMass: nominalMass, root: root, body: body, joint: joint, inertiaPolicy: policy.inertiaPolicy)
        let compiled = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        guard compiled.tree.layout.positionCount == 1, compiled.tree.layout.velocityCount == 1,
              let slot = compiled.tree.layout.joints.first(where: { $0.joint == joint }),
              slot.positions.count == 1, slot.velocities.count == 1 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        self.root = root
        self.body = body
        self.joint = joint
        model = compiled
        positionIndex = slot.positions.start
        velocityIndex = slot.velocities.start
    }

    @inline(never)
    private static func descriptor(identity: String, revision: UInt64, placement: RigidTransform,
        nominalMass: Double, root: EntityID, body: EntityID, joint: EntityID,
        inertiaPolicy: InertiaValidationPolicy) throws -> MechanicalDescriptor {
        let rootRecord = try Self.body(root, mass: 1, mode: .static, placement: placement,
            revision: revision, policy: inertiaPolicy)
        let movingRecord = try Self.body(body, mass: nominalMass, mode: .dynamic, placement: placement,
            revision: revision, policy: inertiaPolicy)
        let record = try JointRecord(id: joint, parentBody: root, childBody: body,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "parameter-identification-parent-anchor"),
                placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "parameter-identification-child-anchor"),
                placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitY)))
        return try MechanicalDescriptor(identity: identity, revision: revision,
            bodies: [.spatial(rootRecord), .spatial(movingRecord)],
            joints: [MechanicalJoint(record: record, authority: .dynamicState)],
            root: root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "parameter-identification-world"),
            initialState: KinematicState(revision: revision, time: 0, q: [0], v: [0], acceleration: [0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never)
    private static func body(_ id: EntityID, mass: Double, mode: BodyMotionMode,
        placement: RigidTransform, revision: UInt64, policy: InertiaValidationPolicy) throws -> BodyRecord3D {
        let tensor = try Matrix3(mass, 0, 0, 0, mass, 0, 0, 0, mass)
        let properties = try MassProperties3D(mass: mass, centerOfMass: .zero,
            inertiaAtCenter: tensor, policy: policy)
        return try BodyRecord3D(id: id, frame: EntityID(kind: .frame, key: id.key + "-frame"),
            mode: mode, bodyToWorld: placement, representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "parameter-identification-known-inertia-shape", revision: revision),
                quality: .exact))
    }

    @inline(never)
    private static func compilationPolicy() throws -> CompilationPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        return try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10,
                characteristicLengthMeters: 1),
            inertiaPolicy: inertia, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 2000, maximumSparsityEntries: 12,
            maximumDependencyEntries: 200, maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
    }
}
