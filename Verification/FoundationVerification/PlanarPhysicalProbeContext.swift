import SwiftMechanics

enum PlanarPhysicalProbeContext {
    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1_000_000, arithmeticOperations: 20_000_000, iterations: 1000))
    }

    static func jointPolicy() throws -> JointEvaluationPolicy {
        try JointEvaluationPolicy(quaternionTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10),
            chartRankRelative: 1e-10, characteristicLengthMeters: 1)
    }

    static func admission(cancelled: Bool = false) throws -> DynamicsAdmission {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 4, maximumVelocities: 8,
            maximumBodyWrenches: 4, maximumGeneralizedContributions: 4), angularVelocityTolerance: tolerance,
            linearVelocityTolerance: tolerance, isCancelled: { cancelled })
    }

    @inline(never)
    static func input(_ model: CompiledMechanicalModel, loads: [BodyWrenchContribution] = []) throws -> PlanarRigidDynamicsInput {
        let state = model.descriptor.initialState
        let kinematics: any TreeKinematicsComputing = TreeKinematicsEvaluator()
        let snapshot = try kinematics.evaluate(model.tree, state: state, policy: jointPolicy())
        var inertias: [PlanarRigidBodyInertia] = []
        for body in model.descriptor.bodies {
            guard case .planar(let record) = body, let inertia = record.inertia else {
                throw FoundationVerificationError.analyticCheckFailed
            }
            inertias.append(try PlanarRigidBodyInertia(body: record.id, frame: record.frame, properties: inertia.properties))
        }
        let gravity = try AffineGravity(frame: model.tree.worldFrame, accelerationAtOrigin: Vector3(0, -10, 0))
        return try PlanarRigidDynamicsInput(snapshot: snapshot, velocity: state.v, inertias: inertias,
            gravity: gravity, bodyWrenches: loads)
    }

    @inline(never)
    static func assemble(_ input: PlanarRigidDynamicsInput) throws -> PhysicalRigidDynamicsSystem {
        var numerical = try work()
        var loads = LoadWork(budget: try LoadBudget(maximumWork: 10000, maximumScalars: 1024))
        let equations: any PhysicalRigidEquationComputing = RigidEquationKernel()
        return try equations.assemble(PhysicalRigidDynamicsInput(planar: input), admission: admission(),
            loadWork: &loads, work: &numerical)
    }

    static func solvePolicy() throws -> DynamicsSolvePolicy {
        try DynamicsSolvePolicy(capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance<Double>(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            coordinateScales: [0.2, 3, 2], energyScale: 7, timeScale: 0.4)
    }

    @inline(never)
    static func geometry(_ model: CompiledMechanicalModel, scale: Double) throws -> GeometricConstraintSystem {
        let first = try GeometricFrameEndpoint(body: PlanarPhysicalProbeModel.id(.body, "first"), frame: PlanarPhysicalProbeModel.id(.frame, "first"))
        let second = try GeometricFrameEndpoint(body: PlanarPhysicalProbeModel.id(.body, "second"), frame: PlanarPhysicalProbeModel.id(.frame, "second"))
        let relation = try GeometricRelation(kind: .distance, rowIDs: [91], first: first, second: second,
            target: GeometricAnalyticTarget(value: Vector3(2, 0, 0)), scale: scale)
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [1, 2], dimensions: [.length, .length],
            scales: [2, 3], timeScale: 3, revision: 1)
        var numerical = try work()
        return try GeometricConstraintSystem(model: model, layout: layout, relations: [relation],
            minimumPosition: [-10, -10], maximumPosition: [10, 10], minimumTime: -1, maximumTime: 1,
            capacity: GeometricConstraintCapacity(maximumBodies: 4, maximumPositions: 2, maximumVelocities: 2,
                maximumRows: 3, maximumMetadataBytes: 32768), work: &numerical)
    }

    static func geometryPolicy(cancelled: Bool = false) throws -> GeometricPhysicalRowPolicy {
        try GeometricPhysicalRowPolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 2, maximumRows: 3,
                expectedLayoutRevision: 1, isCancelled: { cancelled }), maximumBodies: 4,
            originalComparisonTolerance: 1e-10, projectionTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10))
    }
}
