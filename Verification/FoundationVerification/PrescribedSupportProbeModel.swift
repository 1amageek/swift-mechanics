import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class PrescribedSupportProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let base: PrescribedBaseMotionProgram
    let layout: ConstraintCoordinateLayout
    let rootOnly: PrescribedRootProbeModel?

    @inline(never)
    init(slider: Bool) throws {
        if !slider {
            let original = try PrescribedRootProbeModel(planar: true)
            rootOnly = original; model = original.model; base = original.base; layout = original.layout
            return
        }
        rootOnly = nil
        let root = try EntityID(kind: .body, key: "af26-support-root")
        let child = try EntityID(kind: .body, key: "af26-support-slider")
        let rootFrame = try EntityID(kind: .frame, key: "af26-support-root-frame")
        let childFrame = try EntityID(kind: .frame, key: "af26-support-slider-frame")
        let world = try EntityID(kind: .frame, key: "af26-support-world")
        let provenance = try SourceProvenance(source: "af26-support-independent-masses", revision: 1)
        let rootBody = try BodyRecord2D(id: root, frame: rootFrame, mode: .prescribedKinematic,
            bodyToWorld: PlanarPose(x: 0, y: 0, angle: 0), representations: BodyRepresentations(),
            inertia: InertialRepresentation2D(properties: MassProperties2D(mass: 1, centerX: 0,
                centerY: 0, polarInertiaAtCenter: 1), provenance: provenance, quality: .exact))
        let childBody = try BodyRecord2D(id: child, frame: childFrame, mode: .dynamic,
            bodyToWorld: PlanarPose(x: 2, y: 0, angle: 0), representations: BodyRepresentations(),
            inertia: InertialRepresentation2D(properties: MassProperties2D(mass: 2, centerX: 0,
                centerY: 0, polarInertiaAtCenter: 1), provenance: provenance, quality: .exact))
        let joint = try JointRecord(id: EntityID(kind: .joint, key: "af26-support-slider-joint"),
            parentBody: root, childBody: child,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "af26-support-parent-anchor"),
                placement: .fixed(RigidTransform(rotation: .identity, translation: Vector3(2, 0, 0)))),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "af26-support-child-anchor"),
                placement: .fixed(.identity)), manifold: JointManifold(.prismatic(axis: .unitX)))
        let law = try AnalyticPrescribedMotion(frame: rootFrame, parentFrame: world, referenceTime: 0,
            initialPose: .identity, translationRate: .zero, translationAcceleration: Vector3(0, 1, 0),
            rotationAxis: .unitZ, angularRate: 0, angularAcceleration: 0,
            minimumTime: 0, maximumTime: 2, maximumIdentifierBytes: 1024)
        let motionPolicy = try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 1024,
            maximumMetadataBytes: 8192)
        var work = try GeometricProbeContext.work()
        base = try PrescribedBaseMotionProgram(law: law, layout: .planarFloating, policy: motionPolicy, work: &work)
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let inertia = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        let descriptor = try MechanicalDescriptor(identity: "af26-planar-prescribed-support", revision: 1,
            bodies: [.planar(childBody), .planar(rootBody)],
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: root,
            rootBase: .planarFloating, rootAuthority: .prescribedMotion, worldFrame: world,
            initialState: KinematicState(revision: 1, time: 0, q: [0, 0, 0, 0], v: [0, 0, 0, 0],
                acceleration: [0, 1, 0, 0]), representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2,
                maximumVelocities: 4, maximumJacobianScalars: 512),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10,
                characteristicLengthMeters: 1), inertiaPolicy: inertia, translationTolerance: tolerance,
            rotationTolerance: tolerance, maximumRecords: 32, maximumIdentifierBytes: 8192,
            maximumSparsityEntries: 1024, maximumDependencyEntries: 1024, maximumExtensionRecords: 1,
            maximumDiagnostics: 8, extensionBudget: NumericalBudget(scalarStorage: 100,
                arithmeticOperations: 1000, iterations: 10), target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        layout = try ConstraintCoordinateLayout(coordinateIDs: [901, 902, 903, 904],
            dimensions: [.length, .length, .angle, .length], scales: [1, 1, 1, 1], timeScale: 1, revision: 1)
    }
}
