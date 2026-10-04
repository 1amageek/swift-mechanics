import SwiftMechanics

struct MachineFixtures {
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute: 1e-11, relative: 1e-11) }
    static func policy(nodes: Int = 200, records: Int = 200, bytes: Int = 20000, depth: Int = 64, iterations: Int = 20) throws -> MachineDefinitionPolicy {
        try MachineDefinitionPolicy(maximumNodes: nodes, maximumRecords: records, maximumIdentifierBytes: bytes,
            maximumDepth: depth, maximumIterations: iterations)
    }
    static func compilationPolicy() throws -> CompilationPolicy {
        let tolerance = try tolerance()
        return try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 32, maximumVelocities: 96, maximumJacobianScalars: 18432),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 1000,
            maximumIdentifierBytes: 100000, maximumSparsityEntries: 10000, maximumDependencyEntries: 10000,
            maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
    }
    static func body(_ key: String, mode: BodyMotionMode = .dynamic) throws -> BodyRecord3D {
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity,
            policy: InertiaValidationPolicy(symmetry: tolerance(), physicalityRelative: 0)),
            provenance: SourceProvenance(source: "machine-test", revision: 1), quality: .exact)
        return try BodyRecord3D(id: id(.body, key), frame: id(.frame, key + "-frame"), mode: mode,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
    }
    static func hinge() throws -> MechanicalJoint {
        MechanicalJoint(record: try JointRecord(id: id(.joint, "hinge"), parentBody: id(.body, "root"), childBody: id(.body, "child"),
            parentAnchor: JointAnchor(frame: id(.frame, "hinge-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame, "hinge-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.revolute(axis: .unitZ))), authority: .dynamicState)
    }
    static func definition<Content: Machine>(q: [Double] = [0], @MachineBuilder content: () -> Content) throws -> MachineDefinition<Content> {
        try MachineDefinition(identity: "machine-test", revision: 1, root: id(.body, "root"), rootBase: .fixed,
            rootAuthority: .fixed, worldFrame: id(.frame, "world"),
            initialState: KinematicState(revision: 1, time: 0, q: q, v: Array(repeating: 0, count: q.count), acceleration: Array(repeating: 0, count: q.count)), content: content)
    }
}
