import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct MovingBaseProbeModel {
    let model: CompiledMechanicalModel
    let program: PrescribedMotionProgram
    let layout: ConstraintCoordinateLayout
    let firstRotorFrame: EntityID
    let secondRotorFrame: EntityID

    @inline(never)
    init() throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
            inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: SourceProvenance(source: "moving-base-independent-inertia", revision: 1), quality: .exact)
        let keys = ["moving-root", "moving-base", "moving-first", "moving-second"]
        var bodies: [MechanicalBody] = []
        for (index, key) in keys.enumerated() {
            let pose = index == 0 ? RigidTransform.identity : RigidTransform(
                rotation: try UnitQuaternion(axis: .unitZ, angle: index == 1 ? 0.4 : 0.7), translation: try Vector3(0.2, 0.1, 0))
            bodies.append(.spatial(try BodyRecord3D(id: Self.id(.body, key), frame: Self.id(.frame, key + "-frame"),
                mode: index == 0 ? .static : (index == 1 ? .prescribedKinematic : .dynamic), bodyToWorld: pose,
                representations: BodyRepresentations(), inertia: inertia)))
        }
        let anchor = try Self.id(.frame, "moving-base-drive"), rootFrame = try Self.id(.frame, "moving-root-frame")
        let initialPose = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: 0.4), translation: try Vector3(0.2, 0.1, 0))
        let record = try AnalyticPrescribedMotion(frame: anchor, parentFrame: rootFrame, referenceTime: 0, initialPose: initialPose,
            translationRate: Vector3(0.3, 0.4, 0), translationAcceleration: Vector3(0.2, -0.1, 0), rotationAxis: .unitZ,
            angularRate: 0.3, angularAcceleration: 0.2, minimumTime: 0, maximumTime: 2, maximumIdentifierBytes: 256)
        var work = try MechanismProbeContext.work()
        program = try PrescribedMotionProgram(motions: [record], policy: PrescribedMotionPolicy(maximumSamples: 1,
            maximumIdentifierBytes: 256, maximumMetadataBytes: 16384), work: &work)
        let bridge = try JointRecord(id: Self.id(.joint, "moving-bridge"), parentBody: Self.id(.body, keys[0]), childBody: Self.id(.body, keys[1]),
            parentAnchor: JointAnchor(frame: anchor, placement: .prescribed),
            childAnchor: JointAnchor(frame: Self.id(.frame, "moving-bridge-child"), placement: .fixed(.identity)), manifold: JointManifold(.fixed))
        var joints = [MechanicalJoint(record: bridge, authority: .fixed)]
        for key in keys.dropFirst(2) {
            let joint = try JointRecord(id: Self.id(.joint, key), parentBody: Self.id(.body, keys[1]), childBody: Self.id(.body, key),
                parentAnchor: JointAnchor(frame: Self.id(.frame, key + "-parent"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: Self.id(.frame, key + "-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.revolute(axis: .unitZ)))
            joints.append(MechanicalJoint(record: joint, authority: .dynamicState))
        }
        let sample = try PrescribedAnchorState(frame: anchor, time: 0, motion: FrameMotion(pose: initialPose,
            velocity: SpatialMotion(angular: Vector3(0, 0, 0.3), linear: Vector3(0.3, 0.4, 0)),
            acceleration: SpatialMotion(angular: Vector3(0, 0, 0.2), linear: Vector3(0.2, -0.1, 0))))
        let initial = try KinematicState(revision: 1, time: 0, q: [0.3, 0.3], v: [0.1, 0.1], acceleration: [0.3, 0.3], prescribedAnchors: [sample])
        let descriptor = try MechanicalDescriptor(identity: "moving-base-dynamic-public", revision: 1, bodies: bodies, joints: joints,
            root: Self.id(.body, keys[0]), rootBase: .fixed, rootAuthority: .fixed, worldFrame: Self.id(.frame, "moving-world"),
            initialState: initial, representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 1000),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000, maximumExtensionRecords: 8,
            maximumDiagnostics: 8, extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        layout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20], dimensions: [.angle, .angle], scales: [2, 3], timeScale: 5, revision: 1)
        firstRotorFrame = try Self.id(.frame, "moving-first-frame")
        secondRotorFrame = try Self.id(.frame, "moving-second-frame")
    }

    private static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
}
