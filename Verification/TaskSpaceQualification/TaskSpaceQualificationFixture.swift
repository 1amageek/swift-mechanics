import SwiftMechanics

public struct TaskSpaceQualificationFixture: Sendable {
    public let model: CompiledMechanicalModel
    public let inertias: [RigidBodyInertia]
    public let body: EntityID
    public let count: Int

    public init(specifications: [JointSpecification], hingeCenter: Bool = false) throws {
        guard !specifications.isEmpty, specifications.count <= 2 else {
            throw TaskSpaceQualificationError.assertion("Fixture domain requires one or two scalar joints")
        }
        count = specifications.count
        body = try EntityID(kind: .body, key: "task-body-\(count - 1)")
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let provenance = try SourceProvenance(source: "task-space-independent-fixture", revision: 1)
        var bodies: [MechanicalBody] = [], joints: [MechanicalJoint] = []
        for index in -1..<count {
            let key = index < 0 ? "task-root" : "task-body-\(index)"
            let center: Vector3
            if hingeCenter, index >= 0 { center = try Vector3(1, 0, 0) }
            else { center = .zero }
            let properties = try MassProperties3D(mass: index < 0 ? 1 : Double(index + 2),
                centerOfMass: center, inertiaAtCenter: .identity, policy: inertiaPolicy)
            let record = try BodyRecord3D(id: EntityID(kind: .body, key: key), frame: EntityID(kind: .frame, key: key + "-frame"),
                mode: index < 0 ? .static : .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties, provenance: provenance, quality: .exact))
            bodies.append(.spatial(record))
            if index >= 0 {
                let name = "task-joint-\(index)"
                let joint = try JointRecord(id: EntityID(kind: .joint, key: name),
                    parentBody: EntityID(kind: .body, key: index == 0 ? "task-root" : "task-body-\(index - 1)"), childBody: record.id,
                    parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: name + "-parent"), placement: .fixed(.identity)),
                    childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: name + "-child"), placement: .fixed(.identity)),
                    manifold: JointManifold(specifications[index]))
                joints.append(MechanicalJoint(record: joint, authority: .dynamicState))
            }
        }
        let zero = [Double](repeating: 0, count: count)
        let descriptor = try MechanicalDescriptor(identity: "task-space-independent-fixture", revision: 1,
            bodies: bodies, joints: joints, root: EntityID(kind: .body, key: "task-root"), rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "task-world"),
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
        var actual: [RigidBodyInertia] = []
        for treeBody in model.tree.bodies {
            guard let descriptorBody = model.descriptor.bodies.first(where: { $0.id == treeBody.id }),
                  case .spatial(let record) = descriptorBody, let representation = record.inertia else {
                throw TaskSpaceQualificationError.assertion("Original compiled inertia identity missing")
            }
            actual.append(try RigidBodyInertia(body: record.id, frame: record.frame, properties: representation.properties))
        }
        inertias = actual
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

    public func system(position: [Double], velocity: [Double], gravity: Vector3? = nil,
                       knownForces: [GeneralizedForceContribution] = []) throws -> PhysicalRigidDynamicsSystem {
        let state = try model.makeState(KinematicState(revision: model.stamp.revision, time: 3, q: position, v: velocity,
            acceleration: [Double](repeating: 7, count: count)))
        let snapshot = try model.evaluate(state)
        let field: AffineGravity?
        if let gravity { field = try AffineGravity(frame: model.tree.worldFrame, accelerationAtOrigin: gravity) }
        else { field = nil }
        let input = try RigidDynamicsInput(snapshot: snapshot, velocity: velocity, inertias: inertias,
            gravity: field, generalizedForces: knownForces)
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 3, maximumVelocities: 2,
            maximumBodyWrenches: 0, maximumGeneralizedContributions: 1),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        var work = try Self.work(), loads = LoadWork(budget: try LoadBudget(maximumWork: 100000, maximumScalars: 10000))
        return try RigidEquationKernel().assemble(PhysicalRigidDynamicsInput(spatial: input), admission: admission, loadWork: &loads, work: &work)
    }

    public func policy(singularity: TaskSpaceSingularityPolicy = .requireFullRowRank,
                       taskAbsolute: Double = 1e-9, leakAbsolute: Double = 1e-9, taskRelative: Double = 1e-10,
                       coordinateScales: [Double]? = nil, energyScale: Double = 1, timeScale: Double = 1,
                       lengthScale: Double = 1, maximumVelocities: Int = 2, cancelled: Bool = false) throws -> TaskSpacePolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        let scales: [Double]
        if let coordinateScales { scales = coordinateScales }
        else { scales = [Double](repeating: 1, count: count) }
        return try TaskSpacePolicy(maximumVelocities: maximumVelocities, maximumBodies: 3,
            dynamics: DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12),
                coordinateScales: scales, energyScale: energyScale, timeScale: timeScale),
            taskLinearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            taskAccelerationTolerance: NumericalTolerance(absolute: taskAbsolute, relative: taskRelative),
            secondaryLeakTolerance: NumericalTolerance(absolute: leakAbsolute, relative: taskRelative),
            powerTolerance: tolerance, replayTolerance: tolerance, lengthScaleMeters: lengthScale,
            rankRelativeTolerance: 1e-10, singularity: singularity, isCancelled: { cancelled })
    }

    public func request(_ system: PhysicalRigidDynamicsSystem, _ command: TaskSpaceRequest.Command,
                        revision: UInt64 = 1, time: Double = 3, frame: EntityID? = nil) -> TaskSpaceRequest {
        let world: EntityID
        if let frame { world = frame } else { world = model.tree.worldFrame }
        return TaskSpaceRequest(system: system, expectedRevision: revision, expectedTime: time, worldFrame: world, command: command)
    }

    public func motion(axes: [TaskSpaceAxis], acceleration: [Double], weights: [Double],
                       point: Vector3 = .zero, secondary: [Double]? = nil) -> TaskSpaceMotion {
        TaskSpaceMotion(body: body, bodyLocalPoint: point, axes: axes, accelerationMetersPerSecondSquared: acceleration,
            weights: weights, secondaryGeneralizedAcceleration: secondary)
    }

    public static func work(operations: Int = 20_000_000, storage: Int = 1_000_000, iterations: Int = 10000,
                            seeded: Bool = false) throws -> NumericalWork {
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
        if seeded { try work.chargeOperations(11); try work.advanceIteration(); try work.requireStorage(17) }
        return work
    }
}
