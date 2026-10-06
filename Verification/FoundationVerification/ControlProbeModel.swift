import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ControlProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let joint: EntityID
    let parentAnchor: EntityID

    @inline(never)
    init() throws {
        let root = try EntityID(kind: .body, key: "control-public-root")
        let child = try EntityID(kind: .body, key: "control-public-slider")
        joint = try EntityID(kind: .joint, key: "control-public-prismatic")
        parentAnchor = try EntityID(kind: .frame, key: "control-public-parent-anchor")
        let world = try EntityID(kind: .frame, key: "control-public-world")
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let bodies = try Self.bodies(root: root, child: child, inertia: inertia)
        let record = try JointRecord(id: joint, parentBody: root, childBody: child,
            parentAnchor: JointAnchor(frame: parentAnchor, placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "control-public-child-anchor"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitX)))
        let descriptor = try MechanicalDescriptor(identity: "control-public-2kg", revision: 1,
            bodies: bodies, joints: [MechanicalJoint(record: record, authority: .dynamicState)], root: root,
            rootBase: .fixed, rootAuthority: .fixed, worldFrame: world,
            initialState: KinematicState(revision: 1, time: 0, q: [0], v: [0], acceleration: [0]),
            representationRequirements: [], features: [], extensions: [])
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        model = try compiler.compile(descriptor, policy: Self.compilationPolicy(tolerance: tolerance, inertia: inertia))
        try FoundationVerification.require(model.tree.layout.positionCount == 1 && model.tree.layout.velocityCount == 1)
    }

    @inline(never)
    private static func bodies(root: EntityID, child: EntityID, inertia: InertiaValidationPolicy) throws -> [MechanicalBody] {
        var result: [MechanicalBody] = []
        for (id, mass, mode) in [(root, 1.0, BodyMotionMode.static), (child, 2.0, BodyMotionMode.dynamic)] {
            let properties = try MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertia)
            result.append(.spatial(try BodyRecord3D(id: id, frame: EntityID(kind: .frame, key: id.key + "-frame"),
                mode: mode, bodyToWorld: .identity, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties,
                    provenance: SourceProvenance(source: "control-public-physical-oracle", revision: 1), quality: .exact))))
        }
        return result
    }

    @inline(never)
    private static func compilationPolicy(tolerance: NumericalTolerance, inertia: InertiaValidationPolicy) throws -> CompilationPolicy {
        try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 32),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertia, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 32, maximumIdentifierBytes: 4096, maximumSparsityEntries: 64, maximumDependencyEntries: 256,
            maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
    }
}
