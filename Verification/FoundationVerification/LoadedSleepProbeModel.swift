import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct LoadedSleepProbeModel {
    let model: CompiledMechanicalModel
    let layout: ConstraintCoordinateLayout
    let constraints: QuadraticConstraintSystem

    @inline(never)
    init(mass: Double = 2) throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let properties = try MassProperties3D(mass: mass, centerOfMass: .zero, inertiaAtCenter: .identity, policy: inertiaPolicy)
        var bodies: [MechanicalBody] = []
        for (index, key) in ["loaded-root", "loaded-a", "loaded-b"].enumerated() {
            let record = try BodyRecord3D(id: EntityID(kind: .body, key: key), frame: EntityID(kind: .frame, key: key + "-frame"),
                mode: index == 0 ? .static : .dynamic,
                bodyToWorld: RigidTransform(rotation: .identity, translation: Vector3(0, index == 0 ? 0 : -1, 0)),
                representations: BodyRepresentations(), inertia: InertialRepresentation3D(properties: properties,
                    provenance: SourceProvenance(source: "independent-load-sleep-inertia", revision: 1), quality: .exact))
            bodies.append(.spatial(record))
        }
        var joints: [MechanicalJoint] = []
        for key in ["loaded-a", "loaded-b"] {
            let joint = try JointRecord(id: EntityID(kind: .joint, key: key), parentBody: EntityID(kind: .body, key: "loaded-root"),
                childBody: EntityID(kind: .body, key: key),
                parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: key + "-parent"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: key + "-child"), placement: .fixed(.identity)),
                manifold: JointManifold(.prismatic(axis: .unitY)))
            joints.append(MechanicalJoint(record: joint, authority: .dynamicState))
        }
        let initial = try KinematicState(revision: 1, time: 0, q: [-1, -1], v: [0, 0], acceleration: [0, 0])
        let descriptor = try MechanicalDescriptor(identity: "physical-load-sleep-public", revision: 1, bodies: bodies,
            joints: joints, root: EntityID(kind: .body, key: "loaded-root"), rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "loaded-world"), initialState: initial,
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 1000),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 100, maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 8, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        layout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20], dimensions: [.length, .length], scales: [1, 1], timeScale: 1, revision: 1)
        constraints = try QuadraticConstraintSystem(layout: layout,
            rows: [QuadraticConstraint(id: 1, constant: 0, linear: [1, -1], hessian: [0, 0, 0, 0],
                timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0])],
            minimumPosition: [-100, -100], maximumPosition: [100, 100], minimumTime: 0, maximumTime: 10)
    }
}
