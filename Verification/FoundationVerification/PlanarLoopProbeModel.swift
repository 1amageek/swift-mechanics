import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct PlanarLoopProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let root: EntityID
    let crank: EntityID
    let coupler: EntityID
    let rocker: EntityID
    let crankJoint: EntityID
    let couplerJoint: EntityID
    let rockerJoint: EntityID
    let crankIndex: Int
    let couplerIndex: Int
    let rockerIndex: Int
    let polarInertia: Double

    @inline(never)
    init(polarInertia: Double = 1) throws {
        self.polarInertia = polarInertia
        root = try Self.id(.body, "planar-loop-root")
        crank = try Self.id(.body, "planar-loop-crank")
        coupler = try Self.id(.body, "planar-loop-coupler")
        rocker = try Self.id(.body, "planar-loop-rocker")
        crankJoint = try Self.id(.joint, "planar-loop-input")
        couplerJoint = try Self.id(.joint, "planar-loop-coupler-hinge")
        rockerJoint = try Self.id(.joint, "planar-loop-output")
        let properties = try MassProperties2D(mass: 1, centerX: 0, centerY: 0, polarInertiaAtCenter: polarInertia)
        let provenance = try SourceProvenance(source: "independent-planar-loop-inertia", revision: 1)
        let inertia = InertialRepresentation2D(properties: properties, provenance: provenance, quality: .exact)
        let bodies = try [Self.body(root, pose: PlanarPose(x: 0, y: 0, angle: 0), mode: .static, inertia: inertia),
            Self.body(crank, pose: PlanarPose(x: 0, y: 0, angle: .pi / 2), mode: .dynamic, inertia: inertia),
            Self.body(coupler, pose: PlanarPose(x: 0, y: 1, angle: 0), mode: .dynamic, inertia: inertia),
            Self.body(rocker, pose: PlanarPose(x: 2, y: 0, angle: .pi / 2), mode: .dynamic, inertia: inertia)]
        let joints = try [Self.joint(crankJoint, parent: root, child: crank, offset: .zero),
            Self.joint(couplerJoint, parent: crank, child: coupler, offset: Vector3(1, 0, 0)),
            Self.joint(rockerJoint, parent: root, child: rocker, offset: Vector3(2, 0, 0))]
        let capacity = try KinematicCapacity(maximumBodies: 4, maximumVelocities: 3, maximumJacobianScalars: 96)
        let world = try Self.id(.frame, "planar-loop-world")
        let proposed = try KinematicTree(bodies: bodies.map { try $0.kinematicBody() }, joints: joints.map { $0.record },
            root: root, rootBase: .fixed, worldFrame: world, revision: 1, capacity: capacity)
        crankIndex = try Self.index(crankJoint, layout: proposed.layout)
        couplerIndex = try Self.index(couplerJoint, layout: proposed.layout)
        rockerIndex = try Self.index(rockerJoint, layout: proposed.layout)
        var q = [Double](repeating: 0, count: proposed.layout.positionCount)
        q[crankIndex] = .pi / 2; q[couplerIndex] = -.pi / 2; q[rockerIndex] = .pi / 2
        let zero = [Double](repeating: 0, count: proposed.layout.velocityCount)
        let initial = try KinematicState(revision: 1, time: 0, q: q, v: zero, acceleration: zero)
        let descriptor = try MechanicalDescriptor(identity: "planar-loop-public", revision: 1, bodies: bodies,
            joints: joints, root: root, rootBase: .fixed, rootAuthority: .fixed, worldFrame: world,
            initialState: initial, representationRequirements: [], features: [], extensions: [])
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let policy = try CompilationPolicy(kinematicCapacity: capacity,
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 64,
            maximumIdentifierBytes: 8192, maximumSparsityEntries: 1024, maximumDependencyEntries: 1024,
            maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }

    @inline(never)
    private static func body(_ id: EntityID, pose: PlanarPose, mode: BodyMotionMode,
        inertia: InertialRepresentation2D) throws -> MechanicalBody {
        .planar(try BodyRecord2D(id: id, frame: Self.id(.frame, id.key + "-frame"), mode: mode,
            bodyToWorld: pose, representations: BodyRepresentations(), inertia: inertia))
    }

    @inline(never)
    private static func joint(_ id: EntityID, parent: EntityID, child: EntityID, offset: Vector3) throws -> MechanicalJoint {
        MechanicalJoint(record: try JointRecord(id: id, parentBody: parent, childBody: child,
            parentAnchor: JointAnchor(frame: Self.id(.frame, id.key + "-parent"),
                placement: .fixed(RigidTransform(rotation: .identity, translation: offset))),
            childAnchor: JointAnchor(frame: Self.id(.frame, id.key + "-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ))), authority: .dynamicState)
    }

    private static func index(_ id: EntityID, layout: TreeCoordinateLayout) throws -> Int {
        guard let entry = layout.joints.first(where: { $0.joint == id }), entry.positions.count == 1,
              entry.velocities.count == 1, entry.positions.start == entry.velocities.start else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        return entry.positions.start
    }

    private static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
}
