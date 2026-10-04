import SwiftMechanics

/// A fresh public preparation recipe and its independently compiled Runtime carrier.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct GranularRuntimeProbeSource: Sendable {
    let initial: GranularState
    let carrier: CompiledMechanicalModel
    let policy: GranularPolicy
    let physicsBudget: GranularRuntimePhysicsBudget
    let source: GranularRuntimeSource

    @inline(never)
    init(particleMass: Double = 1, seed: UInt64 = 123, timeStepSeconds: Double = 0.001,
         gravityChoices: [Vector3]? = nil,
         maximumAcceptedSteps: Int = 16) throws {
        let policy = try GranularProbeContext.policy(particles: 2, boundaries: 1, contacts: 3, neighbors: 3)
        self.policy = policy
        let initial = try Self.prepare(mass: particleMass, seed: seed, policy: policy)
        self.initial = initial
        let carrier = try Self.compileCarrier(frame: initial.model.frame)
        self.carrier = carrier
        let budget = try Self.physicsBudget()
        physicsBudget = budget
        var work = try Self.work(physics: budget)
        let gravityChoices = try gravityChoices ?? [Vector3(0, 0, -9), Vector3(0, 0, -10)]
        source = try GranularRuntimeSource(initial: initial, carrier: carrier.stamp, policy: policy,
            timeStepSeconds: timeStepSeconds, gravityChoices: gravityChoices,
            maximumAcceptedSteps: maximumAcceptedSteps, contributorID: "granular-public-journal",
            maximumBytes: 16384, maximumMetadataBytes: 8192, physicsBudget: budget, work: &work)
    }

    @inline(never)
    private static func prepare(mass: Double, seed: UInt64, policy: GranularPolicy) throws -> GranularState {
        let motions = try [GranularMotion(position: Vector3(-1, 0, 0.49), velocity: .unitX),
            GranularMotion(position: Vector3(1, 0, 0.49), velocity: Vector3(-1, 0, 0))]
        var particles = [GranularParticle]()
        for i in motions.indices {
            particles.append(try GranularParticle(
                proxy: GranularProbeContext.proxy("p" + String(i), shape: .sphere(radius: 0.5), position: motions[i].position),
                body: GranularProbeContext.ref("p" + String(i), .body),
                material: GranularProbeContext.ref("m" + String(i), .material), mass: mass))
        }
        let boundary = try GranularBoundary(
            proxy: GranularProbeContext.proxy("wall", shape: .halfSpace, position: .zero),
            body: GranularProbeContext.ref("wall", .body), material: GranularProbeContext.ref("wall-material", .material),
            velocityAtOrigin: Vector3(0.25, 0, 0), normalVelocityTolerance: 1e-12, angularAlignmentTolerance: 1e-12)
        let laws = try [GranularProbeContext.pair("m0", "m1", friction: true),
            GranularProbeContext.pair("m0", "wall-material", friction: true),
            GranularProbeContext.pair("m1", "wall-material", friction: true)]
        var numerical = try GranularProbeContext.numerical(), contact = try GranularProbeContext.contactWork()
        var supplier = try GranularProbeContext.supplier()
        let service: any GranularPreparing = ReferenceGranularPreparation()
        return try service.prepare(revision: 1, frame: GranularProbeContext.ref("world", .frame),
            particles: particles, boundaries: [boundary], laws: laws, motions: motions,
            random: RuntimeRandomState(seed: seed), timeSeconds: 0, policy: policy,
            numericalWork: &numerical, contactWork: &contact, supplierWork: &supplier)
    }

    @inline(never)
    private static func compileCarrier(frame: ModelReference) throws -> CompiledMechanicalModel {
        let root = try EntityID(kind: .body, key: "granular-runtime-carrier-root")
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
        let inertia = try InertialRepresentation3D(properties: MassProperties3D(mass: 1, centerOfMass: .zero,
            inertiaAtCenter: .identity, policy: inertiaPolicy),
            provenance: SourceProvenance(source: "granular-public-carrier", revision: 1), quality: .exact)
        let body = MechanicalBody.spatial(try BodyRecord3D(id: root,
            frame: EntityID(kind: .frame, key: "granular-runtime-carrier-frame"), mode: .static,
            bodyToWorld: .identity, representations: BodyRepresentations(), inertia: inertia))
        let descriptor = try MechanicalDescriptor(identity: "granular-runtime-public-carrier", revision: frame.revision,
            bodies: [body], joints: [], root: root, rootBase: .fixed, rootAuthority: .fixed, worldFrame: frame.id,
            initialState: KinematicState(revision: frame.revision, time: 0, q: [], v: [], acceleration: []),
            representationRequirements: [], features: [], extensions: [])
        let policy = try CompilationPolicy(
            kinematicCapacity: KinematicCapacity(maximumBodies: 1, maximumVelocities: 0, maximumJacobianScalars: 0),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 8, maximumIdentifierBytes: 4096, maximumSparsityEntries: 0,
            maximumDependencyEntries: 32, maximumExtensionRecords: 0, maximumDiagnostics: 8,
            extensionBudget: NumericalBudget(scalarStorage: 1024, arithmeticOperations: 10000, iterations: 100),
            target: FoundationVerification.compilerVerificationTarget)
        return try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(descriptor, policy: policy)
    }

    @inline(never)
    static func physicsBudget() throws -> GranularRuntimePhysicsBudget {
        try GranularRuntimePhysicsBudget(
            numerical: NumericalBudget(scalarStorage: 10000, arithmeticOperations: 500000, iterations: 10000),
            collision: CollisionBudget(scalarStorage: 10000, operations: 100000, iterations: 10000, records: 100),
            contact: ContactBudget(operations: 100000, scalarStorage: 10000, records: 100), maximumSupplierCalls: 10000)
    }

    @inline(never)
    static func work(physics: GranularRuntimePhysicsBudget) throws -> GranularRuntimeWork {
        try GranularRuntimeWork(physics: physics, maximumBytes: 400000, maximumWorkUnits: 1000000)
    }
}
