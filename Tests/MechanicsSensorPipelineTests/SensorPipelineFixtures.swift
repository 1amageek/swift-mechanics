import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
enum SensorPipelineFixtures {
    typealias Registry = SensorPipelineContributorHandler<NoRuntimeContributors>
    typealias Base = ReferenceRuntimeCheckpointHandler<Registry, ReferenceModelRevisionUpdater>
    typealias Session = SensorPipelineSession<Base>
    static func id(_ kind: EntityKind, _ key: String) throws -> EntityID { try EntityID(kind: kind, key: key) }
    @inline(never)
    static func model() throws -> CompiledMechanicalModel {
        let t = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let validation = try InertiaValidationPolicy(symmetry: t, physicalityRelative: 0)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: validation),
            provenance: SourceProvenance(source: "sensor-pipeline-mass", revision: 1), quality: .exact)
        let root = try BodyRecord3D(id: id(.body, "root"), frame: id(.frame, "root-frame"), mode: .static,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let body = try BodyRecord3D(id: id(.body, "body"), frame: id(.frame, "body-frame"), mode: .dynamic,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia)
        let joint = try JointRecord(id: id(.joint, "joint"), parentBody: root.id, childBody: body.id,
            parentAnchor: JointAnchor(frame: id(.frame, "parent-anchor"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: id(.frame, "child-anchor"), placement: .fixed(.identity)), manifold: JointManifold(.revolute(axis: .unitZ)))
        let state = try KinematicState(revision: 1, time: 0, q: [0], v: [2], acceleration: [2])
        let descriptor = try MechanicalDescriptor(identity: "sensor-pipeline-model", revision: 1, bodies: [.spatial(root), .spatial(body)],
            joints: [MechanicalJoint(record: joint, authority: .dynamicState)], root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: id(.frame, "world"), initialState: state, representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 4, maximumVelocities: 4, maximumJacobianScalars: 128),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: t, chartRankRelative: 1e-10, characteristicLengthMeters: 1), inertiaPolicy: validation,
            translationTolerance: t, rotationTolerance: t, maximumRecords: 100, maximumIdentifierBytes: 4096, maximumSparsityEntries: 1000,
            maximumDependencyEntries: 1000, maximumExtensionRecords: 8, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }
    static func capacity() throws -> RuntimeCapacity {
        try RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 8, maximumContributorBytes: 1_048_576,
            maximumMetadataBytes: 8192, maximumCheckpointBytes: 2_097_152, maximumValidationWork: 10_000_000,
            maximumValidationScratchBytes: 4_194_304, maximumObservationLeases: 2, maximumBatchStates: 1024,
            maximumTransactions: 10000, maximumStepWorkUnits: 10000, maximumWorkBetweenSafePoints: 4)
    }
    static func channel(id: String = "position", key: UInt64 = 11, quantity: SensorChannel.EncoderQuantity = .position,
                        processing: SensorProcessing? = nil) throws -> SensorChannel {
        let dimension = quantity == .position ? PhysicalDimension.angle : (quantity == .acceleration ? PhysicalDimension(time: -2, angle: 1) : PhysicalDimension(time: -1, angle: 1))
        return try SensorChannel(id: id, streamKey: key, source: .encoder(joint: self.id(.joint, "joint"), quantity: quantity, axis: 0),
            dimension: dimension, processing: processing ?? SensorProcessing())
    }
    static func imu(quantity: SensorChannel.IMUQuantity, axis: Int) throws -> SensorChannel {
        let mount = try ObservationMount(sensor: id(.sensor, "imu"), body: id(.body, "body"), sensorFrame: id(.frame, "imu-frame"),
            sensorToBody: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: Vector3(1, 0, 0)))
        return try SensorChannel(id: quantity == .angularVelocity ? "gyro" : "specific", streamKey: quantity == .angularVelocity ? 22 : 23,
            source: .imu(mount: mount, quantity: quantity, axis: axis, gravityWorld: .zero),
            dimension: quantity == .angularVelocity ? PhysicalDimension(time: -1, angle: 1) : .acceleration, processing: SensorProcessing())
    }
    static func definition(channels: [SensorChannel]? = nil, emitInitial: Bool = false,
                           sampling: SensorPipelineDefinition.Sampling = .endpointOnly,
                           overflow: SensorPipelineDefinition.ReadyOverflow = .refuseOverflow,
                           pending: Int = 1024, ready: Int = 1024, ticks: Int = 1024, seed: UInt64 = 123,
                           period: Double = 0.125) throws -> SensorPipelineDefinition {
        try SensorPipelineDefinition(schemaID: "sensor.pipeline.test.v1", world: "test-world", rootSeed: seed, worldKey: 0,
            initialTimeSeconds: 0, originSeconds: 0, periodSeconds: period, emitInitial: emitInitial, sampling: sampling,
            readyOverflow: overflow, channels: channels ?? [channel()],
            bounds: SensorPipelineBounds(maximumChannels: 16, maximumMetadataBytes: 8192, maximumTicksPerStep: ticks,
                maximumTick: 10000, maximumDraws: 100000, maximumPendingRows: pending, maximumReadyRows: ready,
                maximumBatchRows: 1024, maximumContributorBytes: 1_048_576, maximumDelaySeconds: 100,
                rawBudget: NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10_000_000, iterations: 10000)),
            rawPolicy: ObservationPolicy(maximumBodies: 4, maximumCoordinates: 4, maximumReactionRows: 4, maximumMetadataBytes: 4096))
    }
    @inline(never)
    static func session(definition: SensorPipelineDefinition? = nil, sources: any ObservationSourcePreparing = ReferenceObservationSourcePreparer(),
                        onRelease: (@Sendable () -> Void)? = nil) throws -> Session {
        let model = try self.model(), definition = try definition ?? self.definition(), capacity = try capacity()
        let registry = try Registry(original: NoRuntimeContributors(), definition: definition, capacity: capacity)
        let handler = Base(contributors: registry, revisions: ReferenceModelRevisionUpdater())
        let config = try RuntimeConfiguration(continuation: RuntimeContinuationIdentity(build: "sensor-test-v1", backend: "reference-cpu", precision: "float64"),
            requiredContributors: registry.schemas, capacity: capacity, determinism: .sameBuildReplay, workload: "sensor-pipeline")
        return try Session(model: model, configuration: config, initialState: model.descriptor.initialState, contributors: [], seed: 42,
            definition: definition, checkpoints: handler, sources: sources, onRelease: onRelease)
    }
    static func advance(_ session: any RuntimeSessionOperating, time: Double, q: Double? = nil) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 1)
            try trial.setTime(time); try trial.setPosition(q ?? (2*time + time*time), at: 0)
            try trial.setVelocity(2 + 2*time, at: 0); try trial.setAcceleration(2, at: 0)
            return .accept
        }
    }
    static func request(_ session: Session, after: UInt64 = 0, rows: Int = 1024) throws -> SensorBatchReadRequest {
        try SensorBatchReadRequest(schema: session.definition.schemaID, version: session.definition.version, world: session.definition.world,
            model: session.snapshot().physical.stamp, after: after, maximumRows: rows, maximumScalars: rows)
    }
}
