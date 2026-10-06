import SwiftMechanics

public enum StructuralAuthoringQualificationFixtures {
    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID {
        try EntityID(kind: kind, key: key)
    }

    public static func joint(_ key: String, scope: String? = nil) throws -> EntityID {
        let original = try id(.joint, key)
        return try MachineDefinitionContext.scopedIdentity(original, namespace: scope.map { [$0] } ?? [])
    }

    public static func inertia(_ polar: Double) throws -> InertialRepresentation3D {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let properties = try MassProperties3D(mass: 1, centerOfMass: .zero,
            inertiaAtCenter: Matrix3(polar, 0, 0, 0, polar, 0, 0, 0, polar),
            policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0))
        return InertialRepresentation3D(properties: properties,
            provenance: try SourceProvenance(source: "independent-rotor-inertia", revision: 1), quality: .exact)
    }

    public static func definition(phase: Double = 0, internalMesh: Bool = false,
        antiparallel: Bool = false, passive: Bool = false, torque: Double = 6,
        gear: Bool = true, reverse: Bool = true, scope: String? = nil,
        inconsistentPosition: Bool = false, duplicateGearRow: Bool = false
    ) throws -> StructuralMachineDefinition<AnyMachine> {
        let orientation = antiparallel ? -1.0 : 1.0
        let mesh = internalMesh ? -1.0 : 1.0
        let q1 = 0.4, q2 = (phase - 20 * q1) / (mesh * orientation * 40)
        let v1 = 2.0, v2 = -20 * v1 / (mesh * orientation * 40)
        let aBody = RigidBody(id: try id(.body, "a"), frame: try id(.frame, "a-frame"),
            placement: .connected, representations: try BodyRepresentations(), inertia: try inertia(2)) { EmptyMachine() }
        let bBody = RigidBody(id: try id(.body, "b"), frame: try id(.frame, "b-frame"),
            placement: .connected, representations: try BodyRepresentations(), inertia: try inertia(4)) { EmptyMachine() }
        let childAnchor = RigidTransform(rotation: .identity, translation: try Vector3(0, 0, 0.25))
        let first = try RevoluteJoint(id: id(.joint, "a-spin"), axis: .unitZ,
            parentFrame: id(.frame, "a-parent"), childFrame: id(.frame, "a-child"),
            parentAnchorToBody: RigidTransform(rotation: .identity, translation: Vector3(1, 0, 0)),
            childAnchorToBody: childAnchor, authority: .dynamicState,
            initial: JointInitialState(q: [q1], v: [v1], acceleration: [0])) {
                aBody
            }.placed(at: RigidTransform(rotation: .identity, translation: Vector3(-3, 0, 0)))
        let second = try RevoluteJoint(id: id(.joint, "b-spin"), axis: .unitZ,
            parentFrame: id(.frame, "b-parent"), childFrame: id(.frame, "b-child"),
            parentAnchorToBody: RigidTransform(rotation: .identity, translation: Vector3(-1, 0, 0)),
            childAnchorToBody: childAnchor, authority: .dynamicState,
            initial: JointInitialState(q: [q2 + (inconsistentPosition ? 0.1 : 0)], v: [v2], acceleration: [0])) {
                bBody
            }.placed(at: RigidTransform(rotation: UnitQuaternion(axis: .unitY, angle: antiparallel ? .pi : 0),
                                       translation: Vector3(3, 0, 0)))
        let meshDeclaration = GearMesh(id: try id(.load, "gear"), rowID: 91,
            first: .local(try id(.joint, "a-spin")), second: .local(try id(.joint, "b-spin")),
            firstTeeth: 20, secondTeeth: 40, phaseRadians: phase, phaseScaleRadians: 0.5, internalMesh: internalMesh)
        let duplicate = GearMesh(id: try id(.load, "other-gear"), rowID: 91,
            first: .local(try id(.joint, "a-spin")), second: .local(try id(.joint, "b-spin")),
            firstTeeth: 20, secondTeeth: 40, phaseRadians: phase, phaseScaleRadians: 0.5, internalMesh: internalMesh)
        let motor = TorqueMotor(id: try id(.actuator, "drive"), joint: .local(try id(.joint, "a-spin")), torqueNm: torque)
        let law = try JointSpringDamper(id: id(.load, "spring"), termID: 71,
            joint: .local(id(.joint, "a-spin")), law: PolynomialSpringDamper(coordinateKind: .rotation,
                restCoordinate: 0, quadraticStiffness: 10, linearDamping: 1, maximumDisplacement: 10, maximumRate: 10))
        let root = RigidBody(id: try id(.body, "root"), frame: try id(.frame, "root-frame"),
            placement: .world(bodyToWorld: .identity), representations: try BodyRepresentations(), inertia: try inertia(1)) {
                if reverse { second; first } else { first; second }
                if gear { meshDeclaration }
                if duplicateGearRow { duplicate }
                motor
                if passive { law }
            }.fixed()
        let content: AnyMachine
        if let scope { content = AnyMachine(MachineInstance(id: scope) { root }) }
        else { content = AnyMachine(root) }
        let absoluteRoot = try MachineDefinitionContext.scopedIdentity(id(.body, "root"), namespace: scope.map { [$0] } ?? [])
        return StructuralMachineDefinition(identity: "declared-gears", revision: 1, time: 0, root: absoluteRoot,
            rootBase: .fixed, rootAuthority: .fixed, worldFrame: try id(.frame, "world"),
            baseCoordinates: try BaseCoordinates(q: [], v: []), baseAcceleration: []) { content }
    }

    public static func compilation() throws -> CompilationPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8,
            maximumJacobianScalars: 1024), jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance,
            chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 128,
            maximumIdentifierBytes: 65_536, maximumSparsityEntries: 65_536, maximumDependencyEntries: 65_536,
            maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 100_000, iterations: 1024), target: .nativeCPU)
    }

    public static func definitionPolicy(records: Int = 128) throws -> MachineDefinitionPolicy {
        try MachineDefinitionPolicy(maximumNodes: 256, maximumRecords: records, maximumIdentifierBytes: 65_536,
            maximumDepth: 64, maximumIterations: 16)
    }

    public static func numerical(operations: Int = 20_000_000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: operations, iterations: 100_000))
    }

    public static func loads(operations: Int = 100_000) throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: operations, maximumScalars: 4096))
    }

    public static func actuation(operations: Int = 100_000) throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: operations, maximumScalars: 4096, maximumBytes: 65_536,
            maximumBindings: 16, maximumMetadataBytes: 1024))
    }

    public static func systemPolicy(scope: String? = nil, cancelled: Bool = false) throws -> StructuralSystemPolicy {
        try StructuralSystemPolicy(coordinates: [
            StructuralCoordinateBinding(joint: joint("b-spin", scope: scope), coordinateID: 202, scale: 3,
                minimumPosition: -10, maximumPosition: 10),
            StructuralCoordinateBinding(joint: joint("a-spin", scope: scope), coordinateID: 101, scale: 2,
                minimumPosition: -10, maximumPosition: 10)], timeScale: 5, minimumTime: 0, maximumTime: 10,
            maximumDeclarations: 16, networkID: 801,
            transmission: TransmissionPolicy(maximumCoordinates: 8, maximumPorts: 8, maximumRelations: 8,
                expectedLayoutRevision: 1, expectedModelRevision: 1, geometryTolerance: 1e-10,
                originalTolerance: 1e-8, powerScale: 7, powerTolerance: 1e-8, isCancelled: { cancelled }),
            loadCapacity: StationaryLoadCapacity(maximumPrograms: 1, maximumTermsPerProgram: 8,
                maximumCoordinates: 8, maximumMetadataBytes: 65_536),
            loadSelection: StationaryLoadSelection(programID: 301, revision: 1, generation: 7),
            motorPowerTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10))
    }

    public static func compile(_ definition: StructuralMachineDefinition<AnyMachine>, scope: String? = nil) throws -> StructuralMechanicalSystem {
        var work = try numerical(), transmissions = try numerical(), load = try loads(), drive = try actuation()
        return try definition.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: definitionPolicy(),
            compilationPolicy: compilation(), policy: systemPolicy(scope: scope), work: &work,
            transmissionWork: &transmissions, loadWork: &load, actuationWork: &drive)
    }

    public static func mechanismPolicy() throws -> MechanismSolvePolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-13)
        let lu = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU)
        let cholesky = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4,
            minimumFraction: 1e-7), capability: lu, tolerance: tolerance, referenceScale: 1,
            minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6, derivativeAbsoluteTolerance: 1e-4,
            derivativeRelativeTolerance: 1e-4, maximumFactorEntries: 1024, estimateCondition: false, budget: numerical().budget)
        let constraints = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 8,
            maximumRows: 8, expectedLayoutRevision: 1), diagonalMetric: [1, 1], energyScale: 7,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-8,
            maximumCorrection: 100, nonlinear: nonlinear, linearCapability: cholesky, linearTolerance: tolerance)
        return try MechanismSolvePolicy(dynamics: DynamicsSolvePolicy(capability: cholesky, linearTolerance: tolerance,
            coordinateScales: [2, 3], energyScale: 7, timeScale: 5), constraints: constraints,
            maximumCoordinates: 8, maximumRows: 8, originalTolerance: 1e-8)
    }

    public static func admission() throws -> DynamicsAdmission {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 8, maximumVelocities: 8,
            maximumBodyWrenches: 8, maximumGeneralizedContributions: 8),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
    }
}
