import SwiftMechanics

public enum NonlinearEstimationQualificationFixtures {
    public static let revision: UInt64 = 29
    public static func translated<T>(_ operation: () throws -> T) throws(NonlinearEstimationQualificationError) -> T {
        do { return try operation() }
        catch let error as NonlinearEstimationQualificationError { throw error }
        catch let error as NonlinearEstimatorFailure { throw .estimator(error) }
        catch let error as NonlinearEstimatorCause { throw .cause(error) }
        catch let error as CompilationFailure { throw .compilation(error) }
        catch let error as CoreError { throw .core(error) }
        catch let error as ModelError { throw .model(error) }
        catch let error as JointError { throw .joint(error) }
        catch let error as NumericalError { throw .numerical(error) }
        catch let error as LoadError { throw .load(error) }
        catch let error as ObservationError { throw .observation(error) }
        catch let error as DerivativeError { throw .derivative(error) }
        catch let error as DynamicsError { throw .dynamics(error) }
        catch { throw .unexpectedSupplier }
    }
    public static func id(_ kind: EntityKind, _ name: String) throws -> EntityID {
        try EntityID(kind: kind, key: "ekf-original-" + name)
    }
    public static func work(operations: Int = 50_000_000, storage: Int = 1_000_000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 10_000))
    }
    public static func tolerance() throws -> NumericalTolerance { try NumericalTolerance(absolute: 1e-10, relative: 1e-10) }
    public static func policy(substeps: Int = 32, derivativeCalls: Int = 10000, storage: Int = 1_000_000,
                              coordinate: Double = 20, rate: Double = 20, nis: Double = 1_000_000,
                              covarianceMagnitude: Double = 1_000_000,
                              cancelled: @escaping @Sendable () -> Bool = { false }) throws -> NonlinearEstimatorPolicy {
        let tol = try tolerance(), capability = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky)
        let linear = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-14)
        return try NonlinearEstimatorPolicy(dynamics: DynamicsSolvePolicy(capability: capability, linearTolerance: linear,
            coordinateScales: [1], energyScale: 1, timeScale: 1), derivatives: DerivativePolicy(maximumBodies: 2,
            maximumVelocities: 1, maximumJacobianColumns: 2, tolerance: tol, residualTolerance: tol, physicalNeighborhood: 1e-3,
            inertiaValidation: InertiaValidationPolicy(symmetry: tol, physicalityRelative: 0)),
            observations: ObservationPolicy(maximumBodies: 2, maximumCoordinates: 2, maximumReactionRows: 0, maximumMetadataBytes: 512),
            covarianceCapability: capability, covarianceTolerance: linear, physicalAgreement: tol, covarianceSymmetry: tol,
            maximumSubsteps: substeps, maximumDerivativeCalls: derivativeCalls, maximumScalarStorage: storage, maximumMetadataBytes: 512,
            maximumIntervalSeconds: 2, maximumEffortNewtons: 100, maximumCoordinateMagnitudeMeters: coordinate,
            maximumRateMagnitudeMetersPerSecond: rate, maximumNormalizedCovarianceMagnitude: covarianceMagnitude,
            maximumNormalizedInnovationSquared: nis, isCancelled: cancelled)
    }
    public static func model(identity: String = "original-polynomial-prismatic-model", axis: Vector3 = .unitX) throws -> CompiledMechanicalModel {
        let tol = try tolerance(), validation = try InertiaValidationPolicy(symmetry: tol, physicalityRelative: 0)
        var bodies: [MechanicalBody] = []
        for name in ["root", "moving"] {
            let mass: Double = name == "root" ? 1 : 2
            let properties = try MassProperties3D(mass: mass, centerOfMass: .zero,
                inertiaAtCenter: Matrix3(mass,0,0,0,mass,0,0,0,mass), policy: validation)
            bodies.append(.spatial(try BodyRecord3D(id: id(.body,name), frame: id(.frame,name+"-frame"),
                mode: name == "root" ? .static : .dynamic, bodyToWorld: .identity, representations: BodyRepresentations(),
                inertia: InertialRepresentation3D(properties: properties, provenance: SourceProvenance(source: "original-two-kilogram-slider", revision: revision), quality: .exact))))
        }
        let joint = try JointRecord(id: id(.joint,"slide"), parentBody: id(.body,"root"), childBody: id(.body,"moving"),
            parentAnchor: JointAnchor(frame: id(.frame,"parent-anchor"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame,"child-anchor"), placement: .fixed(.identity)), manifold: JointManifold(.prismatic(axis: axis)))
        let state = try KinematicState(revision: revision, time: 0, q: [0], v: [0], acceleration: [0])
        let descriptor = try MechanicalDescriptor(identity: identity, revision: revision, bodies: bodies,
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: id(.body,"root"), rootBase: .fixed,
            rootAuthority: .fixed, worldFrame: id(.frame,"world"), initialState: state, representationRequirements: [], features: [], extensions: [])
        let compile = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 128),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tol, chartRankRelative: 1e-10, characteristicLengthMeters: 1), inertiaPolicy: validation,
            translationTolerance: tol, rotationTolerance: tol, maximumRecords: 32, maximumIdentifierBytes: 512,
            maximumSparsityEntries: 1000, maximumDependencyEntries: 1000, maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: work().budget, target: .nativeCPU)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: compile)
    }
    public static func law(nonlinear: Bool = true) throws -> PolynomialSpringDamper {
        try PolynomialSpringDamper(coordinateKind: .translation, restCoordinate: 0.1, quadraticStiffness: 3,
            quarticStiffness: nonlinear ? 2 : 0, linearDamping: 0.4, cubicDamping: nonlinear ? 0.6 : 0,
            maximumDisplacement: 20, maximumRate: 20)
    }
    public static func plant(positionScale: Double = 2, rateScale: Double = 3) throws -> PrismaticEstimationModel {
        var ledger = try work()
        return try PrismaticEstimationModel(model: model(), joint: id(.joint,"slide"), passiveLaw: law(),
            positionScaleMeters: positionScale, rateScaleMetersPerSecond: rateScale, policy: policy(), work: &ledger)
    }
    public static func initial(_ plant: PrismaticEstimationModel, time: Double = 2, position: Double = 0.6, rate: Double = -0.4,
                               covariance: [Double] = [0.4,0.1,0.1,0.3]) throws -> NonlinearEstimatorCheckpoint {
        var ledger = try work()
        let service: any NonlinearStateEstimating = ReferenceMechanicalEKF()
        return try service.initialize(plant: plant, timeSeconds: time, positionMeters: position, rateMetersPerSecond: rate,
            normalizedCovariance: covariance, policy: policy(), work: &ledger)
    }
    public static func update(_ checkpoint: NonlinearEstimatorCheckpoint, target: Double = 2.1, substeps: Int = 4,
                              q: [Double] = [0.01,0,0,0.02], effort: Double = 1.5, measurement: NonlinearEstimatorMeasurement? = nil,
                              admittedPolicy: NonlinearEstimatorPolicy? = nil) throws -> NonlinearEstimatorResult {
        var ledger = try work()
        let selected: NonlinearEstimatorPolicy
        if let admittedPolicy { selected = admittedPolicy } else { selected = try policy() }
        let service: any NonlinearStateEstimating = ReferenceMechanicalEKF()
        return try service.update(checkpoint, request: NonlinearEstimatorRequest(targetTimeSeconds: target, heldEffortNewtons: effort,
            substeps: substeps, normalizedProcessCovariance: q, measurement: measurement), policy: selected, work: &ledger)
    }
    public static func reading(_ plant: PrismaticEstimationModel, time: Double, position: Double, delivery: Double? = nil,
                               sequence: UInt64 = 7, variance: Double = 0.16, foreignModel: CompiledMechanicalModel? = nil) throws -> NonlinearEstimatorMeasurement {
        let model = foreignModel ?? plant.model
        let state = try KinematicState(revision: model.stamp.revision, time: time, q: [position], v: [0], acceleration: [0])
        var ledger = try work()
        let source = try ReferenceObservationSourcePreparer().prepare(model: model, state: model.makeState(state), policy: policy().observations, work: &ledger)
        let encoder = try ReferenceKinematicObserver().encoder(source: source, joint: plant.joint, policy: policy().observations, work: &ledger)
        return NonlinearEstimatorMeasurement(encoder: encoder, deliveryTimeSeconds: delivery ?? time, sequence: sequence, positionVarianceSquareMeters: variance)
    }
}
