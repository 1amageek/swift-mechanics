import SwiftMechanics

public struct InertialParametersQualificationFixture: Sendable {
    public let records: [BodyRecord3D]
    public let input: InertialParameterInput
    public let jointPolicy: JointEvaluationPolicy
    public let admission: DynamicsAdmission
    public let solvePolicy: DynamicsSolvePolicy

    public init(coupled: Bool = false, gravity: Bool = false, applied: Bool = false) throws {
        let validation = try Self.validation()
        let count = coupled ? 3 : 2
        var records: [BodyRecord3D] = [], bodies: [KinematicBody] = []
        var inertias: [RigidBodyInertia] = [], bindings: [RigidInertialParameterBinding] = []
        var representations: [InertialRepresentation3D] = []
        for i in 0..<count {
            let properties: MassProperties3D
            if i == 0 { properties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: validation) }
            else {
                properties = try MassProperties3D(mass: i == 1 ? 2 : 2.7,
                    centerOfMass: Vector3(0.4, -0.2 + Double(i - 1)*0.3, 0.1),
                    inertiaAtCenter: Matrix3(2.4, 0.2, -0.1, 0.2, 3.2, 0.15, -0.1, 0.15, 3.6), policy: validation)
            }
            let representation = try InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "inertial-physical-body-\(i)", revision: 4), quality: .exact)
            let record = try BodyRecord3D(id: Self.id(.body, "body-\(i)"), frame: Self.id(.frame, "body-\(i)"),
                mode: .dynamic, bodyToWorld: coupled && i == 0 ? Self.pose(0) : .identity,
                representations: BodyRepresentations(), inertia: representation)
            records.append(record); bodies.append(KinematicBody(body: record)); representations.append(representation)
            inertias.append(try RigidBodyInertia(body: record.id, frame: record.frame, properties: properties))
            bindings.append(try RigidInertialParameterBinding(body: record, modelRevision: 7,
                parameterIDs: (0..<10).map { UInt64(100*i + $0 + 1) }))
        }
        var joints: [JointRecord] = []
        for i in 0..<(count - 1) {
            let specification: JointSpecification = i == 0 ? .revolute(axis: .unitZ) : .prismatic(axis: try Vector3(1, 2, -1))
            joints.append(try JointRecord(id: Self.id(.joint, "joint-\(i)"), parentBody: bodies[i].id, childBody: bodies[i+1].id,
                parentAnchor: JointAnchor(frame: Self.id(.frame, "parent-\(i)"), placement: .fixed(coupled ? Self.pose(2*i+1) : .identity)),
                childAnchor: JointAnchor(frame: Self.id(.frame, "child-\(i)"), placement: .fixed(coupled ? Self.pose(2*i+2) : .identity)),
                manifold: JointManifold(specification)))
        }
        let world = try Self.id(.frame, "world")
        let tree = try KinematicTree(bodies: bodies, joints: joints, root: bodies[0].id, rootBase: .fixed,
            worldFrame: world, revision: 7, capacity: KinematicCapacity(maximumBodies: 3, maximumVelocities: 2, maximumJacobianScalars: 36))
        let state = try KinematicState(revision: 7, time: 3,
            q: coupled ? [0.4, -0.3] : [0], v: coupled ? [1.7, -0.6] : [2], acceleration: coupled ? [-0.7, 1.2] : [3])
        let field: AffineGravity?
        if gravity { field = try AffineGravity(frame: world, accelerationAtOrigin: Vector3(0, -10, 0)) }
        else { field = nil }
        var forces: [GeneralizedForceContribution] = [], wrenches: [BodyWrenchContribution] = []
        if applied {
            forces.append(try GeneralizedForceContribution(values: coupled ? [5, -2] : [5], channel: .applied,
                potentialEnergy: 0, dissipatedPower: 0))
            if coupled {
                wrenches.append(try BodyWrenchContribution(body: bodies[2].id, frame: world, referencePoint: Vector3(0.2, -0.4, 0.6),
                    wrench: SpatialWrench(torque: Vector3(0.3, -0.7, 0.5), force: Vector3(1, -2, 0.4)),
                    channel: .applied, potentialEnergy: 0, dissipatedPower: 0))
            }
        }
        let primal = MechanicalDerivativeInput(tree: tree, state: state, inertias: inertias, gravity: field,
            bodyWrenches: wrenches, generalizedForces: forces, drive: coupled ? [7, -3] : [7])
        self.records = records
        input = InertialParameterInput(primal: primal, bindings: bindings, currentRepresentations: representations,
            mappingPreservesTopology: true, loadsAreParameterIndependent: true)
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        jointPolicy = try JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1)
        admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 3, maximumVelocities: 2,
            maximumBodyWrenches: 1, maximumGeneralizedContributions: 1), angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        solvePolicy = try Self.solve(count: tree.layout.velocityCount)
    }

    public static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: "inertial-" + key) }
    public static func pose(_ i: Int) throws -> RigidTransform {
        try RigidTransform(rotation: UnitQuaternion(axis: Vector3(1, Double(i+2), -1), angle: 0.17*Double(i+1)),
            translation: Vector3(0.3+Double(i)*0.11, -0.4+Double(i)*0.07, 0.2-Double(i)*0.05))
    }
    public static func validation(physicality: Double = 0) throws -> InertiaValidationPolicy {
        try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 1e-12, relative: 1e-12), physicalityRelative: physicality)
    }
    public static func policy(cancelled: @escaping @Sendable () -> Bool = { false }, radius: Double = 1e-3,
                              physicality: Double = 0) throws -> DerivativePolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-9, relative: 1e-10)
        return try DerivativePolicy(maximumBodies: 3, maximumVelocities: 2, maximumJacobianColumns: 2,
            tolerance: tolerance, residualTolerance: tolerance, physicalNeighborhood: radius,
            inertiaValidation: validation(physicality: physicality), isCancelled: cancelled)
    }
    public static func solve(count: Int, pivot: Double = 1e-12) throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: pivot),
            coordinateScales: [Double](repeating: 0.25, count: count), energyScale: 7, timeScale: 3)
    }
    public static func work(operations: Int = 20_000_000, storage: Int = 2_000_000, iterations: Int = 20,
                            seeded: Bool = false) throws -> NumericalWork {
        var work = NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
        if seeded { try work.chargeOperations(11); try work.requireStorage(17); try work.advanceIteration() }
        return work
    }
    public static func loads(seeded: Bool = false) throws -> LoadWork {
        var loads = LoadWork(budget: try LoadBudget(maximumWork: 1_000_000, maximumScalars: 1_000_000))
        if seeded { try loads.charge(5); try loads.reserve(scalars: 7) }
        return loads
    }
    public func direction(body: Int = 1, coordinate: Int? = nil, combined: Bool = false) throws -> [RigidInertialParameterDirection] {
        var result: [RigidInertialParameterDirection] = []
        for i in input.bindings.indices {
            var x = [Double](repeating: 0, count: 10)
            if i == body {
                if let coordinate { x[coordinate] = 1 }
                if combined { x = [0.3, -0.2, 0.1, 0.15, 0.2, -0.3, 0.4, -0.12, 0.08, 0.05] }
            }
            result.append(try RigidInertialParameterDirection(binding: input.bindings[i], mass: x[0],
                firstMoment: Vector3(x[1], x[2], x[3]), inertiaAtOrigin: Matrix3(x[4], x[7], x[8], x[7], x[5], x[9], x[8], x[9], x[6])))
        }
        return result
    }
    public func product(_ direction: [RigidInertialParameterDirection]) throws -> InertialParameterProduct {
        var work = try Self.work(), loads = try Self.loads(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        return try supplier.product(input, direction: direction, jointPolicy: jointPolicy, admission: admission,
            solvePolicy: solvePolicy, policy: Self.policy(), loadWork: &loads, supplierWork: &calls, work: &work)
    }
    public func forward(_ direction: [RigidInertialParameterDirection]) throws -> InertialParameterAccelerationProduct {
        var work = try Self.work(), loads = try Self.loads(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        return try supplier.forwardProduct(input, direction: direction, jointPolicy: jointPolicy, admission: admission,
            solvePolicy: solvePolicy, policy: Self.policy(), loadWork: &loads, supplierWork: &calls, work: &work)
    }
    public func replacing(primal: MechanicalDerivativeInput? = nil, bindings: [RigidInertialParameterBinding]? = nil,
                          representations: [InertialRepresentation3D]? = nil, topology: Bool = true,
                          independent: Bool = true) -> InertialParameterInput {
        let p: MechanicalDerivativeInput, b: [RigidInertialParameterBinding], r: [InertialRepresentation3D]
        if let primal { p = primal } else { p = input.primal }
        if let bindings { b = bindings } else { b = input.bindings }
        if let representations { r = representations } else { r = input.currentRepresentations }
        return InertialParameterInput(primal: p, bindings: b, currentRepresentations: r,
            mappingPreservesTopology: topology, loadsAreParameterIndependent: independent)
    }
    public func primal(state: KinematicState? = nil, inertias: [RigidBodyInertia]? = nil, gravity: AffineGravity? = nil,
                       replaceGravity: Bool = false) -> MechanicalDerivativeInput {
        let original = input.primal
        let s: KinematicState, i: [RigidBodyInertia], g: AffineGravity?
        if let state { s = state } else { s = original.state }
        if let inertias { i = inertias } else { i = original.inertias }
        if replaceGravity { g = gravity } else { g = original.gravity }
        return MechanicalDerivativeInput(tree: original.tree, state: s, inertias: i, gravity: g,
            bodyWrenches: original.bodyWrenches, generalizedForces: original.generalizedForces, drive: original.drive)
    }
}
