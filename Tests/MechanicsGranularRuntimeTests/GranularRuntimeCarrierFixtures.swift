import SwiftMechanics

enum GranularRuntimeCarrierFixtures {
    static func model(revision: UInt64 = 1) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let source = try SourceProvenance(source: "runtime-carrier", revision: revision)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
            inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: source, quality: .exact)
        let root = try BodyRecord3D(id: EntityID(kind: .body, key: "root"), frame: EntityID(kind: .frame, key: "root-frame"),
            mode: .static, bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let descriptor = try MechanicalDescriptor(identity: "granular-test-carrier", revision: revision, bodies: [.spatial(root)], joints: [],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: EntityID(kind: .frame, key: "world"),
            initialState: KinematicState(revision: revision, time: 0, q: [], v: [], acceleration: []),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 32, maximumJacobianScalars: 1536),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 100,
            maximumIdentifierBytes: 10000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
            maximumExtensionRecords: 8, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }
}
