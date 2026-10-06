import CADCore
import CADIR
import SwiftMechanics

@available(macOS 15, *)
public struct ReferenceCADGearReinitializationPreparer: CADGearReinitializationPreparing {
    public init() {}
    public func initialize(document: CADDocument, occurrences: [CADOccurrenceRequest],
                           tolerance: ModelingTolerance, limits: CADGeometryLimits,
                           recipe builder: any CADGearRuntimeRecipeBuilding, runtime: CADGearRuntimePolicy,
                           time: Double, work: inout CADAdapterWork, transmissionWork: inout NumericalWork)
        throws(CADGearReinitializationError) -> CADGearRuntimeContext {
        guard time.isFinite, occurrences.count == 2 else { throw .unsupportedDomain }
        let geometry: CADGeometryAdmission
        do { geometry = try ReferenceCADGeometryAdmitter().admit(document: document, occurrences: occurrences,
            tolerance: tolerance, limits: limits, work: &work) }
        catch { throw .cad(error) }
        let recipe = try builder.makeRecipe(geometry: geometry, time: time)
        try preflight(recipe, geometry: geometry, time: time, work: &work)
        let model: CompiledMechanicalModel
        do { model = try ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()).compile(recipe.descriptor, policy: recipe.compilation) }
        catch { throw .compilation(error) }
        let state: CompiledKinematicState
        do { state = try model.makeState(recipe.descriptor.initialState) }
        catch { throw .compilation(error) }
        let binding: CADGearPairBinding
        do { binding = try ReferenceCADGearBindingPreparer().bind(recipe.gears, geometry: geometry, model: model,
            state: state, layout: recipe.layout, policy: recipe.binding, transmissionPolicy: recipe.transmission,
            work: &work, transmissionWork: &transmissionWork) }
        catch { throw .gear(error) }
        let equations: NonlinearMechanismEquation
        do { equations = try NonlinearMechanismEquation(identity: recipe.equationIdentity, sourceBoundModel: model,
            constraints: binding.network.equations, velocityLayout: recipe.layout, drive: recipe.drive,
            policy: recipe.solve, projection: recipe.projection, admission: recipe.dynamics,
            maximumIdentityBytes: recipe.maximumIdentityBytes) }
        catch { throw .mechanism(error) }
        let continuation: IntegrationContinuationProvider
        do { continuation = try IntegrationContinuationProvider(descriptor: equations.descriptor, policy: recipe.integration) }
        catch { throw .runtime(error) }
        let bytes = try CADGearRecipeEncoding.encode(binding, equations: equations, runtime: runtime, work: &work)
        do throws(RuntimeFailure) {
            let schema = try RuntimeContributorSchema(id: "mechanics.cad.gears.recipe.v1", category: .backend,
                version: 1, maximumBytes: runtime.maximumRecipeBytes)
            let record = try RuntimeContributorState(id: schema.id, category: schema.category, version: schema.version, bytes: bytes)
            let catalog = CADGearRuntimeContributors(admission: _CADGearCatalogAdmission(model: model,
                continuation: continuation, schema: schema, record: record))
            let configuration = try RuntimeConfiguration(continuation: runtime.continuation, requiredContributors: catalog.schemas,
                capacity: runtime.capacity, determinism: runtime.determinism, workload: runtime.workload)
            let base = ReferenceRuntimeCheckpointHandler(contributors: catalog, revisions: ReferenceModelRevisionUpdater())
            let handler = try NonlinearMechanismCheckpointHandler(equations: equations, continuation: continuation,
                base: base, validationBudget: recipe.validation)
            let initial = [record, try continuation.initialRecord(physical: state.state, equations: equations)]
            let checkpoint = try RuntimeCheckpoint(model: model.stamp, continuation: configuration.continuation,
                physical: state.state, contributors: initial, random: RuntimeRandomState(seed: runtime.seed), acceptedSteps: 0)
            _ = try handler.admit(checkpoint, model: model, configuration: configuration, cancellation: nil)
            // The strict original handler checks force even at sequence zero before issuance.
            do { try work.poll() } catch { throw RuntimeFailure(.cancelled, message: "CAD context cancelled before issuance.") }
            return CADGearRuntimeContext(admission: _CADGearRuntimeAdmission(binding: binding, equations: equations,
                continuation: continuation, contributors: catalog, configuration: configuration, checkpoints: handler,
                initialRecords: initial, runtime: runtime))
        } catch { throw .runtime(error) }
    }

    public func prepare(source: CADGearRuntimeContext, expectedSource: RuntimeCheckpoint,
                        document: CADDocument, occurrences: [CADOccurrenceRequest],
                        tolerance: ModelingTolerance, limits: CADGeometryLimits,
                        recipe: any CADGearRuntimeRecipeBuilding, choice: CADGearReinitializationChoice,
                        work: inout CADAdapterWork, transmissionWork: inout NumericalWork)
        throws(CADGearReinitializationError) -> CADPreparedGearReinitialization {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Compatible migration has no original CAD/physical/law certificate.
        // This actual prepare branch must refuse until complete source/target history and physical preservation are proved.
        guard case .reinitialize = choice else { throw .unsupportedMigration }
        do { try work.poll() } catch { throw .cad(error) }
        guard expectedSource.model == source.model.stamp else { throw .staleModel }
        guard expectedSource.acceptedSteps < UInt64.max else { throw .capacityExceeded }
        do { _ = try source.checkpoints.admit(expectedSource, model: source.model,
            configuration: source.configuration, cancellation: nil) }
        catch { throw .runtime(error) }
        let target = try initialize(document: document, occurrences: occurrences, tolerance: tolerance, limits: limits,
            recipe: recipe, runtime: source.runtime, time: expectedSource.physical.time,
            work: &work, transmissionWork: &transmissionWork)
        let oldIdentity = source.binding.geometry.identity, newIdentity = target.binding.geometry.identity
        guard newIdentity.documentID == oldIdentity.documentID, newIdentity != oldIdentity,
              newIdentity.fingerprint != oldIdentity.fingerprint else { throw .staleSource }
        guard target.model.stamp.identity == source.model.stamp.identity,
              target.model.stamp.revision > source.model.stamp.revision else { throw .staleModel }
        guard target.initialPhysical.time.bitPattern == expectedSource.physical.time.bitPattern else { throw .incompatibleTime }
        do throws(RuntimeFailure) {
            var point = [Double](repeating: 0, count: target.equations.descriptor.dimensions.count)
            try target.equations.read(target.initialPhysical, into: &point)
            let reset = try target.continuation.record(acceptedTime: target.initialPhysical.time, point: point,
                nextStep: target.continuation.policy.initialStep, acceptedSteps: expectedSource.acceptedSteps + 1,
                normalizedError: nil)
            let records = [target.contributors.record, reset]
            let checkpoint = try RuntimeCheckpoint(model: target.model.stamp, continuation: target.configuration.continuation,
                physical: target.initialPhysical, contributors: records, random: expectedSource.random,
                acceptedSteps: expectedSource.acceptedSteps + 1)
            _ = try target.checkpoints.admit(checkpoint, model: target.model,
                configuration: target.configuration, cancellation: nil)
            do { try work.poll() } catch { throw RuntimeFailure(.cancelled, message: "CAD reinitialization cancelled before issuance.") }
            let request = RuntimeModelReplacement(expectedSource: expectedSource, model: target.model,
                physical: target.initialPhysical, contributors: records, configuration: target.configuration,
                checkpoints: target.checkpoints)
            return CADPreparedGearReinitialization(admission: _CADGearReinitializationAdmission(source: source,
                target: target, expectedSource: expectedSource, checkpoint: checkpoint, request: request))
        } catch { throw .runtime(error) }
    }

    private func preflight(_ recipe: CADGearRuntimeRecipe, geometry: CADGeometryAdmission, time: Double,
                           work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        do { try work.charge() } catch { throw .cad(error) }
        let descriptor = recipe.descriptor
        guard descriptor.rootBase == .fixed, descriptor.rootAuthority == .fixed,
              descriptor.bodies.count == 3, descriptor.joints.count == 2, descriptor.extensions.isEmpty,
              descriptor.initialState.q.count == 2, descriptor.initialState.v.count == 2,
              descriptor.initialState.acceleration.count == 2, descriptor.initialState.prescribedAnchors.isEmpty,
              recipe.integration.method == .classicalRK4 else { throw .unsupportedDomain }
        guard descriptor.initialState.time.bitPattern == time.bitPattern else { throw .incompatibleTime }
        guard recipe.gears.source == geometry.identity else { throw .staleSource }
        guard recipe.gears.model.identity == descriptor.identity,
              recipe.gears.model.revision == descriptor.revision else { throw .staleModel }
        for body in descriptor.bodies {
            guard case .spatial(let spatial) = body, spatial.inertia != nil,
                  spatial.mode == (spatial.id == descriptor.root ? .static : .dynamic) else { throw .unsupportedDomain }
        }
        for joint in descriptor.joints {
            guard joint.record.parentBody == descriptor.root, joint.authority == .dynamicState,
                  joint.record.manifold.kind == .revolute else { throw .unsupportedDomain }
        }
    }
}

@available(macOS 15, *)
struct _CADGearCatalogAdmission: Sendable {
    let model: CompiledMechanicalModel
    let continuation: IntegrationContinuationProvider
    let schema: RuntimeContributorSchema
    let record: RuntimeContributorState
    fileprivate init(model: CompiledMechanicalModel, continuation: IntegrationContinuationProvider,
                     schema: RuntimeContributorSchema, record: RuntimeContributorState) {
        self.model = model; self.continuation = continuation; self.schema = schema; self.record = record
    }
}

@available(macOS 15, *)
struct _CADGearRuntimeAdmission: Sendable {
    let binding: CADGearPairBinding
    let equations: NonlinearMechanismEquation
    let continuation: IntegrationContinuationProvider
    let contributors: CADGearRuntimeContributors
    let configuration: RuntimeConfiguration
    let checkpoints: NonlinearMechanismCheckpointHandler
    let initialRecords: [RuntimeContributorState]
    let runtime: CADGearRuntimePolicy
    fileprivate init(binding: CADGearPairBinding, equations: NonlinearMechanismEquation,
                     continuation: IntegrationContinuationProvider, contributors: CADGearRuntimeContributors,
                     configuration: RuntimeConfiguration, checkpoints: NonlinearMechanismCheckpointHandler,
                     initialRecords: [RuntimeContributorState], runtime: CADGearRuntimePolicy) {
        self.binding = binding; self.equations = equations; self.continuation = continuation
        self.contributors = contributors; self.configuration = configuration; self.checkpoints = checkpoints
        self.initialRecords = initialRecords; self.runtime = runtime
    }
}

@available(macOS 15, *)
struct _CADGearReinitializationAdmission: Sendable {
    let source: CADGearRuntimeContext
    let target: CADGearRuntimeContext
    let expectedSource: RuntimeCheckpoint
    let checkpoint: RuntimeCheckpoint
    let request: RuntimeModelReplacement
    fileprivate init(source: CADGearRuntimeContext, target: CADGearRuntimeContext,
                     expectedSource: RuntimeCheckpoint, checkpoint: RuntimeCheckpoint, request: RuntimeModelReplacement) {
        self.source = source; self.target = target; self.expectedSource = expectedSource
        self.checkpoint = checkpoint; self.request = request
    }
}
