import Foundation
import CADCore
import CADIR
import SwiftMechanics
import SwiftMechanicsCAD

@available(macOS 15, *)
struct GearReinitializationFixtures {
    let document: CADDocument
    let occurrences: [CADOccurrenceRequest]
    let builder: RecipeBuilder
    let runtime: CADGearRuntimePolicy

    init(document: CADDocument? = nil, scale: Double = 1, revision: UInt64 = 1,
         secondInertia: Double = 3, acceleration: [Double]? = nil,
         spacing: Double? = nil, material suppliedMaterial: Material? = nil) throws {
        let sourceDocument = try document ?? GearBindingFixtures.source()
        self.document = sourceDocument
        let recipeBuilder = RecipeBuilder(revision: revision, spacing: spacing ?? 0.06 * scale,
            secondInertia: secondInertia, acceleration: acceleration)
        builder = recipeBuilder
        let material = suppliedMaterial ?? CADFixtures.material()
        occurrences = try ["first", "second"].enumerated().map { i, key in
            try CADOccurrenceRequest(id: key, sourceFeature: sourceDocument.designGraph.order[i],
                body: GearBindingFixtures.id(.body, key), frame: GearBindingFixtures.id(.frame, key + "-frame"),
                placement: RigidTransform(rotation: .identity, translation: Vector3(i == 0 ? 0 : recipeBuilder.spacing, 0, 0)),
                material: material)
        }
        let capacity = try RuntimeCapacity(maximumPhysicalScalars: 64, maximumContributors: 4,
            maximumContributorBytes: 300_000, maximumMetadataBytes: 200_000, maximumCheckpointBytes: 800_000,
            maximumValidationWork: 2_000_000, maximumValidationScratchBytes: 1_000_000,
            maximumObservationLeases: 2, maximumBatchStates: 2, maximumTransactions: 1000,
            maximumStepWorkUnits: 20_000_000, maximumWorkBetweenSafePoints: 100_000)
        runtime = try CADGearRuntimePolicy(capacity: capacity,
            continuation: RuntimeContinuationIdentity(build: "af30-cad-reinitialize", backend: "native", precision: "float64"),
            determinism: .sameBuildReplay, workload: "two-cad-gears", seed: 123,
            maximumRecipeBytes: 100_000, maximumMetadataBytes: 150_000)
    }
    func context(time: Double = 0) throws -> CADGearRuntimeContext {
        var work = try CADAdapterWork(maximumVisits: 3_000_000), numerical = try GearBindingFixtures.work()
        let port: any CADGearReinitializationPreparing = ReferenceCADGearReinitializationPreparer()
        return try port.initialize(document: document, occurrences: occurrences,
            tolerance: CADFixtures.tolerance, limits: CADFixtures.limits(), recipe: builder,
            runtime: runtime, time: time, work: &work, transmissionWork: &numerical)
    }
    func prepare(source: CADGearRuntimeContext, expected: RuntimeCheckpoint,
                 choice: CADGearReinitializationChoice = .reinitialize) throws -> CADPreparedGearReinitialization {
        var work = try CADAdapterWork(maximumVisits: 3_000_000), numerical = try GearBindingFixtures.work()
        return try ReferenceCADGearReinitializationPreparer().prepare(source: source, expectedSource: expected,
            document: document, occurrences: occurrences, tolerance: CADFixtures.tolerance,
            limits: CADFixtures.limits(), recipe: builder, choice: choice, work: &work, transmissionWork: &numerical)
    }
    static func resized(_ document: CADDocument, scale: Double = 1.1) throws -> CADDocument {
        var result = document
        for id in result.designGraph.order {
            guard var node = result.designGraph.nodes[id], case .involuteGear(var gear) = node.operation else {
                throw CADFixtures.FixtureFailure.missingFeature
            }
            for dimension in [InvoluteGearFeature.Dimension.baseRadius, .pitchRadius, .tipRadius, .rootRadius, .filletRadius] {
                guard case .constant(var quantity) = gear.dimensions[dimension] else { throw CADFixtures.FixtureFailure.missingFeature }
                quantity.value *= scale; gear.dimensions[dimension] = .constant(quantity)
            }
            node.operation = .involuteGear(gear); result.designGraph.nodes[id] = node
        }
        result.designGraph.revision = result.designGraph.revision.advanced()
        return result
    }
    static func session(_ context: CADGearRuntimeContext) throws -> RuntimeSession<NonlinearMechanismCheckpointHandler> {
        try RuntimeSession(model: context.model, configuration: context.configuration,
            initialState: context.initialPhysical, contributors: context.initialRecords,
            seed: context.runtime.seed, checkpoints: context.checkpoints)
    }
    static func draw(_ session: any RuntimeSessionOperating, context: CADGearRuntimeContext) throws {
        let source = session.snapshot().checkpoint
        var point = [Double](repeating: 0, count: context.equations.descriptor.dimensions.count)
        try context.equations.read(source.physical, into: &point)
        let record = try context.continuation.record(acceptedTime: source.physical.time, point: point,
            nextStep: context.continuation.policy.initialStep, acceptedSteps: source.acceptedSteps + 1, normalizedError: nil)
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            _ = try trial.nextRandom(); try trial.replaceContributor(record); return .accept
        }
    }
    static func refuses(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    static func energy(_ context: CADGearRuntimeContext, physical: KinematicState) throws -> MechanicalEnergy {
        let snapshot = try context.model.evaluate(context.model.makeState(physical))
        var inertias: [RigidBodyInertia] = []
        for body in snapshot.bodies {
            guard let record = context.model.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let spatial) = record, let inertia = spatial.inertia else {
                throw CADFixtures.FixtureFailure.missingFeature
            }
            inertias.append(try RigidBodyInertia(body: spatial.id, frame: spatial.frame, properties: inertia.properties))
        }
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 8, maximumVelocities: 8,
            maximumBodyWrenches: 8, maximumGeneralizedContributions: 8),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        var work = try GearBindingFixtures.work(), load = LoadWork(budget: try LoadBudget(maximumWork: 0, maximumScalars: 0))
        let kernel = RigidEquationKernel()
        let system = try kernel.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: physical.v,
            inertias: inertias, gravity: nil), admission: admission, loadWork: &load, work: &work)
        return try kernel.energy(system, acceleration: physical.acceleration, angularMomentumReference: .zero,
            requireComplete: true, work: &work)
    }

    struct RecipeBuilder: CADGearRuntimeRecipeBuilding {
        let revision: UInt64
        let spacing: Double
        let secondInertia: Double
        let acceleration: [Double]?
        func makeRecipe(geometry: CADGeometryAdmission, time: Double) throws(CADGearReinitializationError) -> CADGearRuntimeRecipe {
            do { return try build(geometry: geometry, time: time) }
            catch let error as CADGearReinitializationError { throw error }
            catch let error as CoreError { throw .core(error) }
            catch let error as CompilationFailure { throw .compilation(error) }
            catch let error as ConstraintError { throw .constraint(error) }
            catch let error as RuntimeFailure { throw .runtime(error) }
            catch let error as MechanismError { throw .mechanism(error) }
            catch let error as NumericalError { throw .numerical(error) }
            catch let error as TransmissionError { throw .transmission(error) }
            catch let error as CADGearBindingError { throw .gear(error) }
            catch let error as CADAdapterError { throw .cad(error) }
            catch { throw .incompatibleRecipe }
        }
        private func build(geometry: CADGeometryAdmission, time: Double) throws -> CADGearRuntimeRecipe {
            let tolerance = try NumericalTolerance(absolute: 1e-11, relative: 1e-11)
            let inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0)
            var bodies: [MechanicalBody] = [], joints: [MechanicalJoint] = []
            for (i, key) in ["root", "first", "second"].enumerated() {
                let inertia = [1.0, 2.0, secondInertia][i]
                let pose = RigidTransform(rotation: .identity, translation: try Vector3(i == 2 ? spacing : 0, 0, 0))
                let properties = try MassProperties3D(mass: 1, centerOfMass: .zero,
                    inertiaAtCenter: Matrix3(inertia, 0, 0, 0, inertia, 0, 0, 0, inertia), policy: inertiaPolicy)
                bodies.append(.spatial(try BodyRecord3D(id: GearBindingFixtures.id(.body, key),
                    frame: GearBindingFixtures.id(.frame, key + "-frame"), mode: i == 0 ? .static : .dynamic,
                    bodyToWorld: pose, representations: BodyRepresentations(),
                    inertia: InertialRepresentation3D(properties: properties,
                        provenance: SourceProvenance(source: "explicit-caller-rotor-inertia", revision: revision), quality: .exact))))
                if i > 0 {
                    let record = try JointRecord(id: GearBindingFixtures.id(.joint, key),
                        parentBody: GearBindingFixtures.id(.body, "root"), childBody: GearBindingFixtures.id(.body, key),
                        parentAnchor: JointAnchor(frame: GearBindingFixtures.id(.frame, key + "-parent"), placement: .fixed(pose)),
                        childAnchor: JointAnchor(frame: GearBindingFixtures.id(.frame, key + "-child"), placement: .fixed(.identity)),
                        manifold: JointManifold(.revolute(axis: .unitZ)))
                    joints.append(MechanicalJoint(record: record, authority: .dynamicState))
                }
            }
            let alpha = 1 / (2 + secondInertia / 4)
            let state = try KinematicState(revision: revision, time: time, q: [0, 0], v: [2, -1],
                acceleration: acceleration ?? [alpha, -alpha / 2])
            let descriptor = try MechanicalDescriptor(identity: "cad-runtime-gears", revision: revision,
                bodies: bodies, joints: joints, root: GearBindingFixtures.id(.body, "root"), rootBase: .fixed,
                rootAuthority: .fixed, worldFrame: GearBindingFixtures.id(.frame, "world"), initialState: state,
                representationRequirements: [], features: [], extensions: [])
            let compilation = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 8, maximumVelocities: 8, maximumJacobianScalars: 1000),
                jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-10, characteristicLengthMeters: 1),
                inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance, maximumRecords: 100,
                maximumIdentifierBytes: 100_000, maximumSparsityEntries: 1000, maximumDependencyEntries: 1000,
                maximumExtensionRecords: 8, maximumDiagnostics: 8,
                extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10), target: .nativeCPU)
            let layout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20], dimensions: [.angle, .angle], scales: [2, 3], timeScale: 5, revision: revision)
            let gears = try CADGearPairRequest(freshSource: geometry.identity,
                model: ModelStamp(identity: descriptor.identity, revision: revision),
                first: CADGearShaftRequest(occurrenceID: "first", joint: GearBindingFixtures.id(.joint, "first"),
                    endFace: GearBindingFixtures.endFace(geometry, "first"), mountingPhase: 0),
                second: CADGearShaftRequest(occurrenceID: "second", joint: GearBindingFixtures.id(.joint, "second"),
                    endFace: GearBindingFixtures.endFace(geometry, "second"), mountingPhase: 0),
                phase: 0, phaseScale: 7, networkID: 11, relationID: 41,
                minimumPosition: [-100, -100], maximumPosition: [100, 100], minimumTime: 0, maximumTime: 10, fidelity: .idealExternalSpur)
            let original = try GearBindingFixtures.solvePolicy(), c = original.constraints
            let constraint = try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 8, maximumRows: 8, expectedLayoutRevision: revision),
                diagonalMetric: c.diagonalMetric, energyScale: c.energyScale, rankPolicy: c.rankPolicy,
                rankRelativeTolerance: c.rankRelativeTolerance, originalResidualTolerance: c.originalResidualTolerance,
                maximumCorrection: c.maximumCorrection, nonlinear: c.nonlinear,
                linearCapability: c.linearCapability, linearTolerance: c.linearTolerance)
            let solve = try MechanismSolvePolicy(dynamics: original.dynamics, constraints: constraint,
                maximumCoordinates: 8, maximumRows: 8, originalTolerance: 1e-8)
            let numerical = try GearBindingFixtures.work().budget
            let integration = try ExplicitIntegrationPolicy(method: .classicalRK4, initialStep: 0.01, minimumStep: 1e-8,
                maximumStep: 0.01, safety: 0.9, minimumFactor: 0.2, maximumFactor: 2,
                scales: [.angle, .angle, PhysicalDimension(time: -1, angle: 1), PhysicalDimension(time: -1, angle: 1)].map {
                    try ODEErrorScale(dimension: $0, absoluteSI: 1e-7, relative: 0)
                }, maximumContinuationBytes: 150_000,
                budget: IntegrationBudget(maximumCoordinates: 4, maximumAttempts: 20, maximumAcceptedSteps: 20,
                    maximumOuterArithmetic: 100_000, supplier: numerical))
            return try CADGearRuntimeRecipe(descriptor: descriptor, compilation: compilation, layout: layout, gears: gears,
                binding: GearBindingFixtures.policy(), transmission: TransmissionPolicy(maximumCoordinates: 8, maximumPorts: 8, maximumRelations: 8,
                    expectedLayoutRevision: revision, expectedModelRevision: revision, geometryTolerance: 1e-10,
                    originalTolerance: 1e-8, powerScale: 1, powerTolerance: 1e-8),
                equationIdentity: "cad-gears-original-physical", drive: [1, 0], solve: solve,
                projection: NonlinearMechanismProjectionPolicy(position: constraint, maximumIterations: 8, maximumCorrection: 100),
                dynamics: DynamicsAdmission(capacity: DynamicsCapacity(maximumBodies: 8, maximumVelocities: 8, maximumBodyWrenches: 8, maximumGeneralizedContributions: 8),
                    angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance),
                integration: integration, validation: numerical, maximumIdentityBytes: 100_000)
        }
    }
}
