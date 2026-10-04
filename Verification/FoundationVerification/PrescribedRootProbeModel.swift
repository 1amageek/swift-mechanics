import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct PrescribedRootProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let layout: ConstraintCoordinateLayout
    let base: PrescribedBaseMotionProgram
    let planar: Bool
    let mass: Double
    let center: Vector3

    @inline(never)
    init(planar: Bool, angularAcceleration: Double = 0.3, inertiaScale: Double = 1) throws {
        self.planar = planar
        mass = 2
        center = try Vector3(0.4, -0.3, planar ? 0 : 0.2)
        let bodyID = try EntityID(kind: .body, key: "af25-root-only-body")
        let frame = try EntityID(kind: .frame, key: "af25-root-only-frame")
        let world = try EntityID(kind: .frame, key: "af25-root-only-world")
        let pose = try RigidTransform(rotation: UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4),
            translation: Vector3(1, 2, planar ? 0 : 3))
        let law = try AnalyticPrescribedMotion(frame: frame, parentFrame: world, referenceTime: 0,
            initialPose: pose, translationRate: Vector3(0.4, -0.2, planar ? 0 : 0.1),
            translationAcceleration: Vector3(0.3, 0.2, planar ? 0 : -0.1), rotationAxis: .unitZ,
            angularRate: 0.2, angularAcceleration: angularAcceleration, minimumTime: 0, maximumTime: 2,
            maximumIdentifierBytes: 1024)
        let motionPolicy = try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 1024,
            maximumMetadataBytes: 8192)
        var work = try GeometricProbeContext.work()
        let baseLayout: BaseLayout = planar ? .planarFloating : .spatialFloating
        base = try PrescribedBaseMotionProgram(law: law, layout: baseLayout, policy: motionPolicy, work: &work)
        let sample = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(base, time: 0,
            policy: motionPolicy, sampler: AnalyticPrescribedBaseMotionSampler(), work: &work)
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let provenance = try SourceProvenance(source: "af25-prescribed-root-public-oracle", revision: 1)
        let body: MechanicalBody
        if planar {
            let properties = try MassProperties2D(mass: mass, centerX: center.x, centerY: center.y,
                polarInertiaAtCenter: 5*inertiaScale)
            body = .planar(try BodyRecord2D(id: bodyID, frame: frame, mode: .prescribedKinematic,
                bodyToWorld: PlanarPose(x: 1, y: 2, angle: 0.4), representations: BodyRepresentations(),
                inertia: InertialRepresentation2D(properties: properties, provenance: provenance, quality: .exact)))
        } else {
            let properties = try MassProperties3D(mass: mass, centerOfMass: center,
                inertiaAtCenter: Matrix3(3*inertiaScale, 0, 0, 0, 4*inertiaScale, 0, 0, 0, 5*inertiaScale),
                policy: inertiaPolicy)
            body = .spatial(try BodyRecord3D(id: bodyID, frame: frame, mode: .prescribedKinematic,
                bodyToWorld: pose, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties, provenance: provenance, quality: .exact)))
        }
        let capacity = try KinematicCapacity(maximumBodies: 1, maximumVelocities: 6,
            maximumJacobianScalars: 64)
        let descriptor = try MechanicalDescriptor(identity: "af25-prescribed-root-public", revision: 1,
            bodies: [body], joints: [], root: bodyID, rootBase: baseLayout, rootAuthority: .prescribedMotion,
            worldFrame: world, initialState: KinematicState(revision: 1, time: 0, q: sample.q, v: sample.v,
                acceleration: sample.a), representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: capacity,
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10,
                characteristicLengthMeters: 1), inertiaPolicy: inertiaPolicy, translationTolerance: tolerance,
            rotationTolerance: tolerance, maximumRecords: 16, maximumIdentifierBytes: 4096,
            maximumSparsityEntries: 1024, maximumDependencyEntries: 1024, maximumExtensionRecords: 1,
            maximumDiagnostics: 8, extensionBudget: NumericalBudget(scalarStorage: 100,
                arithmeticOperations: 1000, iterations: 10), target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        let n = baseLayout.velocityCount
        let dimensions: [PhysicalDimension] = planar ? [.length, .length, .angle] :
            [.length, .length, .length, .angle, .angle, .angle]
        layout = try ConstraintCoordinateLayout(coordinateIDs: (0..<n).map { UInt64(301+$0) },
            dimensions: dimensions, scales: planar ? [2, 3, 4] : [2, 3, 4, 5, 6, 7], timeScale: 2, revision: 1)
    }
}
