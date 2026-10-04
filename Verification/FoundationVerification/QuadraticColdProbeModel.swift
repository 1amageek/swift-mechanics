import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct QuadraticColdProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let root: EntityID
    let a: EntityID
    let b: EntityID
    let c: EntityID
    let aJoint: EntityID
    let bJoint: EntityID
    let cJoint: EntityID
    let aPosition: Int
    let bPosition: Int
    let cPosition: Int
    let aVelocity: Int
    let bVelocity: Int
    let cVelocity: Int
    let constraints: QuadraticConstraintSystem
    let drive: [Double]

    @inline(never)
    init(mass: Double = 2) throws {
        root = try Self.id(.body, "quadratic-cold-root")
        a = try Self.id(.body, "quadratic-cold-a")
        b = try Self.id(.body, "quadratic-cold-b")
        c = try Self.id(.body, "quadratic-cold-c")
        aJoint = try Self.id(.joint, "quadratic-cold-a-slide")
        bJoint = try Self.id(.joint, "quadratic-cold-b-slide")
        cJoint = try Self.id(.joint, "quadratic-cold-c-slide")
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let bodies = try [Self.body(root, mass: 1, mode: .static, policy: inertiaPolicy),
            Self.body(a, mass: mass, mode: .dynamic, policy: inertiaPolicy),
            Self.body(b, mass: mass, mode: .dynamic, policy: inertiaPolicy),
            Self.body(c, mass: mass, mode: .dynamic, policy: inertiaPolicy)]
        let joints = try [Self.joint(aJoint, parent: root, child: a), Self.joint(bJoint, parent: root, child: b),
            Self.joint(cJoint, parent: root, child: c)]
        let zero = [Double](repeating: 0, count: 3)
        let descriptor = try MechanicalDescriptor(identity: "quadratic-cold-public", revision: 1, bodies: bodies,
            joints: joints, root: root, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: Self.id(.frame, "quadratic-cold-world"),
            initialState: KinematicState(revision: 1, time: 0, q: zero, v: zero, acceleration: zero),
            representationRequirements: [], features: [], extensions: [])
        let compilerPolicy = try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 4, maximumVelocities: 16, maximumJacobianScalars: 384),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 64, maximumIdentifierBytes: 16384, maximumSparsityEntries: 4096,
            maximumDependencyEntries: 4096, maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 10000, iterations: 100),
            target: FoundationVerification.compilerVerificationTarget)
        let compiled = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: compilerPolicy)
        model = compiled
        let aSlot = try Self.scalarSlot(aJoint, model: compiled), bSlot = try Self.scalarSlot(bJoint, model: compiled)
        let cSlot = try Self.scalarSlot(cJoint, model: compiled)
        aPosition = aSlot.position; bPosition = bSlot.position; cPosition = cSlot.position
        aVelocity = aSlot.velocity; bVelocity = bSlot.velocity; cVelocity = cSlot.velocity
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [101, 102, 103], dimensions: [.length, .length, .length],
            scales: [1, 1, 1], timeScale: 1, revision: compiled.stamp.revision)
        var first = zero, second = zero, effort = zero
        first[aPosition] = 1; first[bPosition] = -1
        second[bPosition] = 1; second[cPosition] = -1
        effort[aVelocity] = 4; effort[bVelocity] = -4
        constraints = try QuadraticConstraintSystem(layout: layout,
            rows: [Self.row(11, linear: first), Self.row(12, linear: second)],
            minimumPosition: [-100, -100, -100], maximumPosition: [100, 100, 100], minimumTime: 0, maximumTime: 10)
        drive = effort
    }

    @inline(never)
    private static func body(_ id: EntityID, mass: Double, mode: BodyMotionMode,
        policy: InertiaValidationPolicy) throws -> MechanicalBody {
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: mass, centerOfMass: .zero,
            inertiaAtCenter: .identity, policy: policy), provenance: SourceProvenance(source: "quadratic-cold-independent-inertia", revision: 1), quality: .exact)
        return .spatial(try BodyRecord3D(id: id, frame: Self.id(.frame, id.key + "-frame"), mode: mode,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia))
    }

    @inline(never)
    private static func joint(_ id: EntityID, parent: EntityID, child: EntityID) throws -> MechanicalJoint {
        MechanicalJoint(record: try JointRecord(id: id, parentBody: parent, childBody: child,
            parentAnchor: JointAnchor(frame: Self.id(.frame, id.key + "-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: Self.id(.frame, id.key + "-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitY))), authority: .dynamicState)
    }

    private static func row(_ id: UInt64, linear: [Double]) -> QuadraticConstraint {
        QuadraticConstraint(id: id, constant: 0, linear: linear, hessian: [Double](repeating: 0, count: 9),
            timeLinear: 0, timeQuadratic: 0, mixedTime: [Double](repeating: 0, count: 3))
    }

    private static func scalarSlot(_ id: EntityID, model: CompiledMechanicalModel) throws -> (position: Int, velocity: Int) {
        guard let entry = model.tree.layout.joints.first(where: { $0.joint == id }),
              entry.positions.count == 1, entry.velocities.count == 1 else { throw FoundationVerificationError.analyticCheckFailed }
        return (entry.positions.start, entry.velocities.start)
    }

    private static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
}
