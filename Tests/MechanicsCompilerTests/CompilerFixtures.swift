import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsCompiler

struct CompilerFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute: 1e-11, relative: 1e-11) }
    static func inertiaPolicy(relative: Double = 0) throws -> InertiaValidationPolicy {
        try InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: relative)
    }
    static func policy(records: Int = 1000, sparsity: Int = 10000, dependencies: Int = 10000,
                       operations: Int = 1000, target: CompilerTarget = .nativeCPU) throws -> CompilationPolicy {
        try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 32, maximumVelocities: 96, maximumJacobianScalars: 18432),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance(), chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy(), translationTolerance: tolerance(), rotationTolerance: tolerance(),
            maximumRecords: records, maximumIdentifierBytes: 100000, maximumSparsityEntries: sparsity,
            maximumDependencyEntries: dependencies, maximumExtensionRecords: 32, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: operations, iterations: 10), target: target)
    }
    static func body(_ key: String, planar: Bool = false, mode: BodyMotionMode = .dynamic,
                     pose: RigidTransform = .identity, mass: Double = 1, display: String? = nil,
                     tensor: Matrix3 = .identity, physicality: Double = 0, quality: InertialQuality = .exact) throws -> MechanicalBody {
        let source = try SourceProvenance(source: "fixture", revision: 1)
        let geometry: GeometryRepresentation?
        if let display { geometry = try GeometryRepresentation(kind: .displayGeometry, assetKey: display, provenance: source, quality: .exact) }
        else { geometry = nil }
        let representations = try BodyRepresentations(displayGeometry: geometry)
        if planar {
            return .planar(try BodyRecord2D(id: id(.body, key), frame: id(.frame, key + "-frame"), mode: mode,
                bodyToWorld: PlanarPose(x: pose.translation.x, y: pose.translation.y, angle: pose.rotation.rotationVector().z), representations: representations,
                inertia: InertialRepresentation2D(properties: MassProperties2D(mass: mass, centerX: 0, centerY: 0, polarInertiaAtCenter: 1), provenance: source, quality: quality)))
        }
        return .spatial(try BodyRecord3D(id: id(.body, key), frame: id(.frame, key + "-frame"), mode: mode,
            bodyToWorld: pose, representations: representations,
            inertia: InertialRepresentation3D(properties: MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: tensor,
                policy: inertiaPolicy(relative: physicality)), provenance: source, quality: quality)))
    }
    static func joint(_ key: String = "hinge", parent: String = "root", child: String = "child",
                      specification: JointSpecification = .revolute(axis: .unitZ), authority: CoordinateAuthority = .dynamicState,
                      parentPlacement: AnchorPlacement = .fixed(.identity), childPlacement: AnchorPlacement = .fixed(.identity)) throws -> MechanicalJoint {
        MechanicalJoint(record: try JointRecord(id: id(.joint, key), parentBody: id(.body, parent), childBody: id(.body, child),
            parentAnchor: JointAnchor(frame: id(.frame, key + "-parent"), placement: parentPlacement),
            childAnchor: JointAnchor(frame: id(.frame, key + "-child"), placement: childPlacement), manifold: JointManifold(specification)), authority: authority)
    }
    static func descriptor(revision: UInt64 = 1, identity: String = "fixture-model", bodies: [MechanicalBody]? = nil,
                           joints: [MechanicalJoint]? = nil, base: BaseLayout = .fixed, authority: CoordinateAuthority = .fixed,
                           q: [Double] = [0], v: [Double] = [0], acceleration: [Double]? = nil,
                           anchors: [PrescribedAnchorState] = [], requirements: [BodyRepresentationRequirement] = [],
                           features: [FeatureRequirement] = [], extensions: [MechanicalExtensionRecord] = []) throws -> MechanicalDescriptor {
        try MechanicalDescriptor(identity: identity, revision: revision,
            bodies: bodies ?? [body("root", mode: .static), body("child")], joints: joints ?? [joint()],
            root: id(.body, "root"), rootBase: base, rootAuthority: authority, worldFrame: id(.frame, "world"),
            initialState: KinematicState(revision: revision, time: 0, q: q, v: v, acceleration: acceleration ?? Array(repeating: 0, count: v.count), prescribedAnchors: anchors),
            representationRequirements: requirements, features: features, extensions: extensions)
    }
    static func compile(_ descriptor: MechanicalDescriptor, policy: CompilationPolicy? = nil) throws -> CompiledMechanicalModel {
        try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy ?? self.policy())
    }
    static func failure(_ code: CompilationCode, record: EntityID? = nil,
                        operation: () throws(CompilationFailure) -> Void) {
        do { try operation(); Issue.record("Expected compilation failure was not returned.") }
        catch {
            #expect(error.diagnostics.first?.code == code)
            if let record { #expect(error.diagnostics.contains { $0.records.contains(record) }) }
        }
    }
}
