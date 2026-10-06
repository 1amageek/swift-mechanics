import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum ImplicitMethodsQualificationFixtures {
    public typealias Handler = ReferenceRuntimeCheckpointHandler<ImplicitQualificationContributors, ReferenceModelRevisionUpdater>
    public typealias Session = RuntimeSession<Handler>
    public static func translated<T>(_ operation: () throws -> T) throws(ImplicitMethodsQualificationError) -> T {
        do { return try operation() }
        catch let error as ImplicitMethodsQualificationError { throw error }
        catch let error as ImplicitIntegrationFailure { throw .implicitStep(error) }
        catch let error as StructuralImplicitFailure { throw .structuralStep(error) }
        catch let error as ImplicitMethodCause { throw .method(error) }
        catch let error as RuntimeFailure { throw .runtime(error) }
        catch let error as NumericalError { throw .numerical(error) }
        catch let error as CoreError { throw .core(error) }
        catch let error as ModelError { throw .model(error) }
        catch let error as JointError { throw .joint(error) }
        catch let error as LoadError { throw .load(error) }
        catch let error as CompilationFailure { throw .compilation(error) }
        catch { throw .unexpectedSupplier }
    }
    public static func require(_ condition: Bool, _ message: String) throws(ImplicitMethodsQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    public static func near(_ value: Double, _ expected: Double, absolute: Double = 2e-10,
                            relative: Double = 2e-10, _ message: String) throws(ImplicitMethodsQualificationError) {
        try require(value.isFinite && expected.isFinite && abs(value-expected) <= absolute+relative*max(abs(value), abs(expected)), message)
    }
    public static func model(_ physics: ImplicitQualificationPhysics, revision: UInt64 = 97)
        throws(ImplicitMethodsQualificationError) -> CompiledMechanicalModel {
        try translated {
            func id(_ kind: EntityKind, _ key: String) throws(ModelError) -> EntityID { try EntityID(kind: kind, key: key) }
            let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
            let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
            let provenance = try SourceProvenance(source: "original-implicit-physical-model", revision: revision)
            let fixedInertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
                inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: provenance, quality: .exact)
            let movingInertia = try InertialRepresentation3D(properties: MassProperties3D(mass: physics.mass, centerOfMass: .zero,
                inertiaAtCenter: .identity, policy: inertiaPolicy), provenance: provenance, quality: .exact)
            let fixed = try BodyRecord3D(id: id(.body, "implicit-root"), frame: id(.frame, "implicit-root-frame"), mode: .static,
                bodyToWorld: .identity, representations: BodyRepresentations(), inertia: fixedInertia)
            let moving = try BodyRecord3D(id: id(.body, "implicit-moving"), frame: id(.frame, "implicit-moving-frame"), mode: .dynamic,
                bodyToWorld: RigidTransform(rotation: .identity, translation: Vector3(0.25, 0, 0)),
                representations: BodyRepresentations(), inertia: movingInertia)
            let joint = try JointRecord(id: id(.joint, "implicit-prismatic"), parentBody: fixed.id, childBody: moving.id,
                parentAnchor: JointAnchor(frame: id(.frame, "implicit-parent-anchor"), placement: .fixed(.identity)),
                childAnchor: JointAnchor(frame: id(.frame, "implicit-child-anchor"), placement: .fixed(.identity)),
                manifold: JointManifold(.prismatic(axis: .unitX)))
            let initial = try KinematicState(revision: revision, time: 0, q: [0.25], v: [-0.2],
                acceleration: [physics.acceleration(q: 0.25, v: -0.2)])
            let descriptor = try MechanicalDescriptor(identity: "original-implicit-physical-model", revision: revision,
                bodies: [.spatial(fixed), .spatial(moving)], joints: [MechanicalJoint(record: joint, authority: .dynamicState)],
                root: fixed.id, rootBase: .fixed, rootAuthority: .fixed, worldFrame: id(.frame, "implicit-world"),
                initialState: initial, representationRequirements: [], features: [], extensions: [])
            let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 0, characteristicLengthMeters: 1),
                inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
                maximumRecords: 16, maximumIdentifierBytes: 4096, maximumSparsityEntries: 128, maximumDependencyEntries: 128,
                maximumExtensionRecords: 0, maximumDiagnostics: 8,
                extensionBudget: NumericalBudget(scalarStorage: 128, arithmeticOperations: 10000, iterations: 16), target: .nativeCPU)
            return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
        }
    }
    public static func nonlinear(operations: Int = 200000, storage: Int = 4096, iterations: Int = 256,
                                 factors: Int = 64) throws(ImplicitMethodsQualificationError) -> NonlinearPolicy<Double> {
        try translated {
            try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-8),
                capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
                tolerance: LinearTolerance(absoluteResidual: 1e-12, relativeResidual: 1e-12, pivotThreshold: 1e-14),
                referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
                derivativeAbsoluteTolerance: 1e-5, derivativeRelativeTolerance: 1e-5,
                maximumFactorEntries: factors, estimateCondition: false,
                budget: NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
        }
    }
    public static func eulerPolicy(operations: Int = 200000, storage: Int = 4096, iterations: Int = 256,
                                   factors: Int = 64) throws(ImplicitMethodsQualificationError) -> ImplicitEulerPolicy {
        try translated {
            try ImplicitEulerPolicy(scales: [ODEErrorScale(dimension: .length, absoluteSI: 0.25, relative: 0.1),
                ODEErrorScale(dimension: PhysicalDimension(length: 1, time: -1), absoluteSI: 0.5, relative: 0.1)],
                nonlinear: nonlinear(operations: operations, storage: storage, iterations: iterations, factors: factors))
        }
    }
    public static func structuralPolicy(_ parameters: GeneralizedAlphaParameters, operations: Int = 200000,
                                        storage: Int = 4096, iterations: Int = 256) throws(ImplicitMethodsQualificationError) -> StructuralImplicitPolicy {
        try translated { try StructuralImplicitPolicy(parameters: parameters,
            residualScales: [StructuralResidualScale(dimension: .force, referenceSI: 3)],
            nonlinear: nonlinear(operations: operations, storage: storage, iterations: iterations)) }
    }
    public static func session(_ model: CompiledMechanicalModel, physics: ImplicitQualificationPhysics,
                                q: Double = 0.25, v: Double = -0.2, stepWork: Int = 10000,
                                category: RuntimeContributorCategory = .actuator) throws(ImplicitMethodsQualificationError) -> Session {
        try translated {
            let contributors = try ImplicitQualificationContributors(category: category)
            let configuration = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "original-implicit-qualification",
                backend: "reference-cpu", precision: "float64"), requiredContributors: contributors.schemas,
                capacity: RuntimeCapacity(maximumPhysicalScalars: 3, maximumContributors: 1, maximumContributorBytes: 1,
                    maximumMetadataBytes: 4096, maximumCheckpointBytes: 8192, maximumValidationWork: 4096,
                    maximumValidationScratchBytes: 1000, maximumObservationLeases: 1, maximumBatchStates: 1,
                    maximumTransactions: 1024, maximumStepWorkUnits: stepWork, maximumWorkBetweenSafePoints: 4),
                determinism: .sameBuildReplay, workload: "original-implicit-mass-spring-damper-load")
            return try Session(model: model, configuration: configuration,
                initialState: KinematicState(revision: model.stamp.revision, time: 0, q: [q], v: [v], acceleration: [physics.acceleration(q: q, v: v)]),
                contributors: [contributors.initialRecord()], seed: 831,
                checkpoints: Handler(contributors: contributors, revisions: ReferenceModelRevisionUpdater()))
        }
    }
    public static func structuralInput(_ provider: ImplicitQualificationStructural, q: Double = 0.25, v: Double = -0.2)
        throws(ImplicitMethodsQualificationError) -> StructuralIntegrationState {
        try translated { try StructuralIntegrationState(descriptor: provider.descriptor, time: 0,
            displacement: [q], velocity: [v], acceleration: [provider.physics.acceleration(q: q, v: v)]) }
    }
}
