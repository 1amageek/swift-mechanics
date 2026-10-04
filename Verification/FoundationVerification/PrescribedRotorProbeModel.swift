import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct PrescribedRotorProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let base: PrescribedBaseMotionProgram
    let layout: ConstraintCoordinateLayout
    let planar: Bool
    let firstRotor: EntityID
    let secondRotor: EntityID
    let firstRotorFrame: EntityID
    let secondRotorFrame: EntityID
    let firstPosition: Int
    let secondPosition: Int
    let firstVelocity: Int
    let secondVelocity: Int

    @inline(never)
    init(planar: Bool) throws {
        self.planar = planar
        let root = try Self.id(.body, "prescribed-rotor-root"), rootFrame = try Self.id(.frame, "prescribed-rotor-root-frame")
        let world = try Self.id(.frame, "prescribed-rotor-world")
        firstRotor = try Self.id(.body, "prescribed-rotor-first")
        secondRotor = try Self.id(.body, "prescribed-rotor-second")
        firstRotorFrame = try Self.id(.frame, "prescribed-rotor-first-frame")
        secondRotorFrame = try Self.id(.frame, "prescribed-rotor-second-frame")
        let initialPose = try RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: 0.4), translation: Vector3(1, 2, 0))
        let law = try AnalyticPrescribedMotion(frame: rootFrame, parentFrame: world, referenceTime: 0, initialPose: initialPose,
            translationRate: Vector3(0.4, -0.2, 0), translationAcceleration: Vector3(0.3, 0.2, 0),
            rotationAxis: .unitZ, angularRate: 0.2, angularAcceleration: 0.3,
            minimumTime: 0, maximumTime: 2, maximumIdentifierBytes: 1024)
        let motionPolicy = try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 1024, maximumMetadataBytes: 8192)
        var work = try GeometricProbeContext.work()
        let rootLayout: BaseLayout = planar ? .planarFloating : .spatialFloating
        base = try PrescribedBaseMotionProgram(law: law, layout: rootLayout, policy: motionPolicy, work: &work)
        let sample = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(base, time: 0,
            policy: motionPolicy, sampler: AnalyticPrescribedBaseMotionSampler(), work: &work)
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let provenance = try SourceProvenance(source: "prescribed-rotor-public-independent-inertia", revision: 1)
        var bodies: [MechanicalBody] = [], kinematic: [KinematicBody] = []
        for (index, id) in [root, firstRotor, secondRotor].enumerated() {
            let frame = [rootFrame, firstRotorFrame, secondRotorFrame][index]
            let inertia = [2.0, 2.0, 3.0][index], angle = index == 0 ? 0.4 : 0.65
            if planar {
                let record = try BodyRecord2D(id: id, frame: frame, mode: index == 0 ? .prescribedKinematic : .dynamic,
                    bodyToWorld: PlanarPose(x: 1, y: 2, angle: angle), representations: BodyRepresentations(),
                    inertia: InertialRepresentation2D(properties: MassProperties2D(mass: 1, centerX: 0, centerY: 0,
                        polarInertiaAtCenter: inertia), provenance: provenance, quality: .exact))
                bodies.append(.planar(record)); kinematic.append(try KinematicBody(body: record))
            } else {
                let record = try BodyRecord3D(id: id, frame: frame, mode: index == 0 ? .prescribedKinematic : .dynamic,
                    bodyToWorld: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: angle), translation: Vector3(1, 2, 0)),
                    representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: MassProperties3D(mass: 1,
                        centerOfMass: .zero, inertiaAtCenter: Matrix3(inertia, 0, 0, 0, inertia, 0, 0, 0, inertia), policy: inertiaPolicy),
                        provenance: provenance, quality: .exact))
                bodies.append(.spatial(record)); kinematic.append(KinematicBody(body: record))
            }
        }
        var joints: [MechanicalJoint] = []
        for (body, key) in [(firstRotor, "prescribed-rotor-first-joint"), (secondRotor, "prescribed-rotor-second-joint")] {
            let joint = try JointRecord(id: Self.id(.joint, key), parentBody: root, childBody: body,
                parentAnchor: JointAnchor(frame: Self.id(.frame, key + "-parent"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: Self.id(.frame, key + "-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.revolute(axis: .unitZ)))
            joints.append(MechanicalJoint(record: joint, authority: .dynamicState))
        }
        joints.sort { $0.record.id.key < $1.record.id.key }
        let capacity = try KinematicCapacity(maximumBodies: 3, maximumVelocities: 8, maximumJacobianScalars: 1024)
        let tree = try KinematicTree(bodies: kinematic, joints: joints.map { $0.record }, root: root, rootBase: rootLayout,
            worldFrame: world, revision: 1, capacity: capacity)
        var q = [Double](repeating: 0, count: tree.layout.positionCount)
        var v = [Double](repeating: 0, count: tree.layout.velocityCount), a = v
        for index in sample.q.indices { q[index] = sample.q[index] }
        for index in sample.v.indices { v[index] = sample.v[index]; a[index] = sample.a[index] }
        for entry in tree.layout.joints {
            q[entry.positions.start] = 0.25; v[entry.velocities.start] = 0.4; a[entry.velocities.start] = -0.1
        }
        let descriptor = try MechanicalDescriptor(identity: planar ? "prescribed-planar-rotors-public" : "prescribed-spatial-rotors-public",
            revision: 1, bodies: bodies, joints: joints, root: root, rootBase: rootLayout, rootAuthority: .prescribedMotion,
            worldFrame: world, initialState: KinematicState(revision: 1, time: 0, q: q, v: v, acceleration: a),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: capacity,
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 64, maximumIdentifierBytes: 8192, maximumSparsityEntries: 2048, maximumDependencyEntries: 2048,
            maximumExtensionRecords: 1, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        guard let first = model.tree.layout.joints.first(where: { $0.joint == joints[0].record.id }),
              let second = model.tree.layout.joints.first(where: { $0.joint == joints[1].record.id }) else { throw FoundationVerificationError.analyticCheckFailed }
        firstPosition = first.positions.start; secondPosition = second.positions.start
        firstVelocity = first.velocities.start; secondVelocity = second.velocities.start
        let rootDimensions: [PhysicalDimension] = planar ? [.length, .length, .angle] : [.length, .length, .length, .angle, .angle, .angle]
        let n = model.tree.layout.velocityCount
        layout = try ConstraintCoordinateLayout(coordinateIDs: (0..<n).map { UInt64(401 + $0) },
            dimensions: rootDimensions + [.angle, .angle], scales: (0..<n).map { Double(2 + $0) }, timeScale: 2, revision: 1)
    }

    private static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
}
