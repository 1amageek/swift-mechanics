import SwiftMechanics

public struct JointStopQualificationFixture: Sendable {
    public let model: CompiledMechanicalModel
    public let inertias: [RigidBodyInertia]
    public let joint: EntityID
    public let count: Int

    public init(specification: JointSpecification, serial: Bool = false) throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let provenance = try SourceProvenance(source: "joint-stop-independent-fixture", revision: 1)
        count = serial ? 2 : 1
        joint = try EntityID(kind: .joint, key: "stop-joint-0")
        var bodies: [MechanicalBody] = [], joints: [MechanicalJoint] = []
        for index in -1..<count {
            let key = index < 0 ? "stop-root" : "stop-body-\(index)"
            let center: Vector3
            if case .revolute = specification, index >= 0 { center = try Vector3(1, 0, 0) }
            else { center = .zero }
            let properties = try MassProperties3D(mass: index < 0 ? 1 : Double(index + 2),
                centerOfMass: center, inertiaAtCenter: .identity, policy: inertiaPolicy)
            let body = try BodyRecord3D(id: EntityID(kind: .body, key: key), frame: EntityID(kind: .frame, key: key + "-frame"),
                mode: index < 0 ? .static : .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties, provenance: provenance, quality: .exact))
            bodies.append(.spatial(body))
            if index >= 0 {
                let name = "stop-joint-\(index)"
                let record = try JointRecord(id: EntityID(kind: .joint, key: name),
                    parentBody: EntityID(kind: .body, key: index == 0 ? "stop-root" : "stop-body-\(index - 1)"), childBody: body.id,
                    parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: name + "-parent"), placement: .fixed(.identity)),
                    childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: name + "-child"), placement: .fixed(.identity)),
                    manifold: JointManifold(specification))
                joints.append(MechanicalJoint(record: record, authority: .dynamicState))
            }
        }
        let zero = [Double](repeating: 0, count: count)
        let descriptor = try MechanicalDescriptor(identity: "joint-stop-independent-fixture", revision: 1,
            bodies: bodies, joints: joints, root: EntityID(kind: .body, key: "stop-root"), rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "stop-world"),
            initialState: KinematicState(revision: 1, time: 0, q: zero, v: zero, acceleration: zero),
            representationRequirements: [], features: [], extensions: [])
        let compilePolicy = try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 3, maximumVelocities: 2, maximumJacobianScalars: 36),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 100, maximumIdentifierBytes: 4096, maximumSparsityEntries: 256,
            maximumDependencyEntries: 1024, maximumExtensionRecords: 0, maximumDiagnostics: 10,
            extensionBudget: NumericalBudget(scalarStorage: 256, arithmeticOperations: 10000, iterations: 100), target: Self.target)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        model = try compiler.compile(descriptor, policy: compilePolicy)
        var actualInertias: [RigidBodyInertia] = []
        for treeBody in model.tree.bodies {
            guard let descriptorBody = model.descriptor.bodies.first(where: { $0.id == treeBody.id }),
                  case .spatial(let record) = descriptorBody, let representation = record.inertia else {
                throw JointStopQualificationError.assertion("Original compiled inertia identity missing")
            }
            actualInertias.append(try RigidBodyInertia(body: record.id, frame: record.frame, properties: representation.properties))
        }
        inertias = actualInertias
    }

    private static var target: CompilerTarget {
        #if arch(wasm32)
        #if hasFeature(Embedded)
        .embeddedWasiPreview1
        #else
        .wasiPreview1
        #endif
        #else
        .nativeCPU
        #endif
    }

    public func input(position: [Double], velocity: [Double], unit: PhysicalDimension = .length,
                      lower: Double = 0, upper: Double = 2, metric: Double = 1, restitution: Double = 0.5,
                      threshold: Double = 0, wrap: JointWrapPolicy = .unwrapped,
                      stamp: ModelStamp? = nil, continuousLoss: Bool = false) throws -> JointStopInput {
        let state = try model.makeState(KinematicState(revision: model.stamp.revision, time: 3,
            q: position, v: velocity, acceleration: [Double](repeating: 7, count: count)))
        let definition = try JointStopDefinition(model: stamp ?? model.stamp, joint: joint, coordinateUnit: unit,
            lower: lower, upper: upper, wrap: wrap, metersPerCoordinateUnit: metric,
            restitutionLaw: Self.law(restitution: restitution, threshold: threshold, continuousLoss: continuousLoss))
        return JointStopInput(model: model, state: state, inertias: inertias, definition: definition, expectedTimeSeconds: 3)
    }

    public static func law(restitution: Double, threshold: Double, continuousLoss: Bool = false) throws -> ContactLawPair {
        func material(_ key: String) throws -> ContactMaterial {
            try ContactMaterial(reference: ModelReference(id: EntityID(kind: .material, key: key), revision: 1),
                youngModulus: 1e6, poissonsRatio: 0.2, linearStiffness: 2000, normalDamping: 0,
                huntCrossleyAlpha: 0, friction: .none,
                resistance: ContactResistanceParameters(rollingCoefficient: 0, spinningCoefficient: 0, angularRegularization: 0.1), cohesion: .none)
        }
        var work = ContactWork(budget: try ContactBudget(operations: 10000, scalarStorage: 1024, records: 10))
        let pairing: any ContactMaterialPairing = SeriesContactPairing()
        return try pairing.combine(first: material("stop-first"), second: material("stop-second"),
            selection: .linear(maximumPenetration: 1, maximumNormalSpeed: 100),
            lossPolicy: continuousLoss ? .compliantDampingOnly : .separateImpact(restitution: restitution, thresholdSpeed: threshold),
            resistanceRadius: 1, override: nil, work: &work)
    }

    public func policy(cancelled: Bool = false) throws -> JointStopPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        return try JointStopPolicy(
            observations: ObservationPolicy(maximumBodies: 3, maximumCoordinates: 2, maximumReactionRows: 2,
                maximumMetadataBytes: 4096, isCancelled: { cancelled }),
            constraints: ConstraintEvaluationPolicy(maximumCoordinates: 2, maximumRows: 2,
                expectedLayoutRevision: model.stamp.revision, isCancelled: { cancelled }),
            admission: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 3, maximumVelocities: 2,
                maximumBodyWrenches: 0, maximumGeneralizedContributions: 0),
                angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance, isCancelled: { cancelled }),
            mass: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12),
                coordinateScales: [Double](repeating: 1, count: count), energyScale: 1, timeScale: 1),
            gapToleranceMeters: 1e-9, speedToleranceMetersPerSecond: 1e-9, minimumInverseMassPerKilogram: 1e-12,
            impulseScales: [Double](repeating: 1, count: count), momentumTolerance: tolerance, energyToleranceJoules: tolerance)
    }

    public static func work(operations: Int = 20_000_000, storage: Int = 1_000_000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 10000))
    }

    public static func loadWork() throws -> LoadWork {
        LoadWork(budget: try LoadBudget(maximumWork: 100000, maximumScalars: 10000))
    }

    public static func contactWork() throws -> ContactWork {
        ContactWork(budget: try ContactBudget(operations: 100000, scalarStorage: 10000, records: 100))
    }
}
