import SwiftMechanics

public enum PoseIKQualificationFixtures {
    public static let revision: UInt64 = 107
    public static let source = "original-pose-query-spatial-source"
    public static func translated<T>(_ operation: () throws -> T) throws(PoseIKQualificationError) -> T {
        do { return try operation() }
        catch let e as PoseIKQualificationError { throw e }
        catch let e as PoseIKFailure { throw .pose(e) }
        catch let e as PoseIKError { throw .admission(e) }
        catch let e as NonlinearCause { throw .equation(e) }
        catch let e as CompilationFailure { throw .compilation(e) }
        catch let e as CoreError { throw .core(e) }
        catch let e as ModelError { throw .model(e) }
        catch let e as JointError { throw .joint(e) }
        catch let e as ConstraintError { throw .constraint(e) }
        catch let e as DerivativeError { throw .derivative(e) }
        catch let e as NumericalError { throw .numerical(e) }
        catch { throw .unexpectedSupplier }
    }
    public static func require(_ value: Bool, _ message: String) throws(PoseIKQualificationError) {
        guard value else { throw .assertion(message) }
    }
    public static func near(_ value: Double, _ expected: Double, tolerance: Double = 2e-8,
                            _ message: String) throws(PoseIKQualificationError) {
        try require(value.isFinite && expected.isFinite && abs(value-expected) <= tolerance*(1+abs(expected)), message)
    }
    public static func model(rotating: Bool = false, redundant: Bool = false) throws(PoseIKQualificationError) -> CompiledMechanicalModel {
        try translated {
            let n = rotating ? 6 : (redundant ? 4 : 3)
            func id(_ kind: EntityKind, _ key: String) throws(ModelError) -> EntityID { try EntityID(kind: kind, key: "pose-"+key) }
            let tolerance = try NumericalTolerance(absolute: 1e-11, relative: 1e-11)
            let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
            let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 2, centerOfMass: .zero,
                inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: SourceProvenance(source: source, revision: revision), quality: .exact)
            let rootPose = RigidTransform(rotation: .identity, translation: try Vector3(1, -2, 0.5))
            let parent = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: .pi/2), translation: .zero)
            let child = RigidTransform(rotation: .identity, translation: try Vector3(0.1, 0.2, -0.1))
            let movingPose = try rootPose.composed(with: parent).composed(with: child.inverted())
            var bodies: [MechanicalBody] = [], joints: [MechanicalJoint] = []
            for i in 0...n {
                bodies.append(.spatial(try BodyRecord3D(id: id(.body, "body-\(i)"), frame: id(.frame, "body-frame-\(i)"),
                    mode: i == 0 ? .static : .dynamic, bodyToWorld: i == 0 ? rootPose : movingPose,
                    representations: BodyRepresentations(), inertia: inertia)))
            }
            let axes: [Vector3] = rotating ? [.unitX, .unitY, .unitZ, .unitZ, .unitY, .unitX] : [.unitX, .unitY, .unitZ, .unitX]
            for i in 0..<n {
                let record = try JointRecord(id: id(.joint, "joint-\(i)"), parentBody: bodies[i].id, childBody: bodies[i+1].id,
                    parentAnchor: JointAnchor(frame: id(.frame, "parent-\(i)"), placement: .fixed(i == 0 ? parent : .identity)),
                    childAnchor: JointAnchor(frame: id(.frame, "child-\(i)"), placement: .fixed(i == 0 ? child : .identity)),
                    manifold: JointManifold(rotating && i >= 3 ? .revolute(axis: axes[i]) : .prismatic(axis: axes[i])))
                joints.append(MechanicalJoint(record: record, authority: .dynamicState))
            }
            let zero = [Double](repeating: 0, count: n)
            let descriptor = try MechanicalDescriptor(identity: source, revision: revision, bodies: bodies, joints: joints,
                root: bodies[0].id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: id(.frame, "world"),
                initialState: KinematicState(revision: revision, time: 0, q: zero, v: zero, acceleration: zero),
                representationRequirements: [], features: [], extensions: [])
            let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 384),
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-12, characteristicLengthMeters: 1),
                inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
                maximumRecords: 64, maximumIdentifierBytes: 8192, maximumSparsityEntries: 1024, maximumDependencyEntries: 1024,
                maximumExtensionRecords: 0, maximumDiagnostics: 8,
                extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 10000, iterations: 16), target: .nativeCPU)
            return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        }
    }
    public static func policy(storage: Int = 2_000_000, operations: Int = 100_000_000, iterations: Int = 3000,
                              factors: Int = 4096, calls: Int = 9,
                              cancel: @escaping @Sendable () -> Bool = { false },
                              derivativeCancel: @escaping @Sendable () -> Bool = { false }) throws(PoseIKQualificationError) -> PoseIKPolicy {
        try translated {
            let budget = try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations)
            let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
            let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-8),
                capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
                tolerance: LinearTolerance(absoluteResidual: 1e-11, relativeResidual: 1e-11, pivotThreshold: 1e-13),
                referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
                derivativeAbsoluteTolerance: 2e-5, derivativeRelativeTolerance: 2e-5,
                maximumFactorEntries: factors, estimateCondition: false, budget: budget)
            return try PoseIKPolicy(maximumCoordinates: 8, maximumRows: 8, maximumBodies: 8, maximumIdentityBytes: 8192,
                maximumDerivativeCallsPerDirection: calls, loopTolerance: 1e-9, rankRelativeTolerance: 1e-10,
                joint: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-12, characteristicLengthMeters: 1),
                derivative: DerivativePolicy(maximumBodies: 8, maximumVelocities: 8, maximumJacobianColumns: 64,
                    tolerance: tolerance, residualTolerance: tolerance, physicalNeighborhood: 1,
                    inertiaValidation: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0), isCancelled: derivativeCancel),
                nonlinear: nonlinear, budget: budget, isCancelled: cancel)
        }
    }
    public static func problem(_ model: CompiledMechanicalModel, tasks: [PoseIKTask], initial: [Double]? = nil,
                               reference: [Double]? = nil, scales: [Double]? = nil, lower: [Double]? = nil, upper: [Double]? = nil,
                               loops: QuadraticConstraintSystem? = nil, time: Double = 3,
                               branch: PoseIKBranch = .suppliedLocal(cosineMargin: 0.1), revision: UInt64 = PoseIKQualificationFixtures.revision)
        throws(PoseIKQualificationError) -> PoseIKProblem {
        try translated {
            let n = model.tree.layout.velocityCount, zero = [Double](repeating: 0, count: n)
            let dimensions = model.tree.joints.flatMap { $0.manifold.orderedAxes.map { $0.kind == .prismatic ? PhysicalDimension.length : .angle } }
            return PoseIKProblem(identity: "original-local-pose-query", tree: model.tree,
                layout: try ConstraintCoordinateLayout(coordinateIDs: (0..<n).map { UInt64(100+$0) }, dimensions: dimensions,
                    scales: scales ?? (0..<n).map { 0.5+0.25*Double($0) }, timeScale: 2, revision: revision),
                worldFrame: model.tree.worldFrame, time: time, initialPositions: initial ?? zero, referencePositions: reference ?? zero,
                minimumPositions: lower ?? [Double](repeating: -2, count: n), maximumPositions: upper ?? [Double](repeating: 2, count: n),
                tasks: tasks, loops: loops, branch: branch)
        }
    }
    public static func target(_ q: [Double], local: Vector3 = .zero) throws(PoseIKQualificationError) -> RigidTransform {
        try translated {
            let xyz = PoseIKQualificationOracle.point(q, local: [local.x, local.y, local.z], rotating: q.count == 6, redundant: q.count == 4)
            var rotation = try UnitQuaternion(axis: .unitZ, angle: .pi/2)
            if q.count == 6 {
                rotation = try rotation.multiplied(by: UnitQuaternion(axis: .unitZ, angle: q[3]))
                    .multiplied(by: UnitQuaternion(axis: .unitY, angle: q[4])).multiplied(by: UnitQuaternion(axis: .unitX, angle: q[5]))
            }
            return RigidTransform(rotation: rotation, translation: try Vector3(xyz[0], xyz[1], xyz[2]))
        }
    }
    public static func point(_ model: CompiledMechanicalModel, target: Vector3, local: Vector3 = .zero,
                             bodyIndex: Int? = nil) -> PoseIKTask {
        let body = model.tree.bodies[bodyIndex ?? (model.tree.bodies.count-1)]
        return .point(rowIDs: [1, 2, 3], body: body.id, bodyFrame: body.frame, localPoint: local, targetWorld: target,
            lengthScale: 0.7, toleranceMeters: 2e-8)
    }
    public static func pose(_ model: CompiledMechanicalModel, target: RigidTransform, local: Vector3 = .zero) -> PoseIKTask {
        let body = model.tree.bodies[model.tree.bodies.count-1]
        return .pose(rowIDs: [1, 2, 3, 4, 5, 6], body: body.id, bodyFrame: body.frame, localPoint: local, targetWorld: target,
            lengthScale: 0.7, angularScale: 0.6, toleranceMeters: 2e-8, matrixTolerance: 2e-8)
    }
    public static func solve(_ problem: PoseIKProblem, policy: PoseIKPolicy? = nil) throws(PoseIKQualificationError) -> PoseIKResult {
        let p: PoseIKPolicy
        if let policy { p = policy } else { p = try self.policy() }
        let solver: any PoseIKSolving = BoundedPoseIKSolver()
        return try translated { try solver.solve(problem, policy: p) }
    }
    public static func refusal(_ problem: PoseIKProblem, policy: PoseIKPolicy? = nil,
                               check: (PoseIKFailure) throws(PoseIKQualificationError) -> Void) throws(PoseIKQualificationError) {
        let p: PoseIKPolicy
        if let policy { p = policy } else { p = try self.policy() }
        do { _ = try BoundedPoseIKSolver().solve(problem, policy: p) }
        catch { try check(error); return }
        throw .assertion("Expected the original typed PoseIK refusal.")
    }
}
