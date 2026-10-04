import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyPlanarReactionLower() throws {
        let model = try PlanarPhysicalProbeModel.pendulum()
        try checkPlanarPendulumReaction(PlanarPhysicalProbeContext.assemble(PlanarPhysicalProbeContext.input(model)), appliedX: 0)
        try checkPlanarShiftedRawReaction(model)
        try checkPlanarPhysicalAllocation(FourBarProbeModel(planar: true))
        print("AF25 planar tree/support and physical-allocation lower witnesses passed.")
    }

    @inline(never)
    private static func checkPlanarPendulumReaction(_ system: PhysicalRigidDynamicsSystem, appliedX: Double) throws {
        guard case .planar(let source) = system.input.source else { throw FoundationVerificationError.analyticCheckFailed }
        let service: any PlanarTreeReactionRecovering = PlanarTreeReactionRecovery()
        var work = try GeometricProbeContext.work()
        var load = LoadWork(budget: try LoadBudget(maximumWork: 1000, maximumScalars: 1024))
        let report = try service.recover(system, acceleration: [-10.0/3], topology: .completeTree,
            outputFrame: source.snapshot.tree.worldFrame, policy: ReactionPathProbeContext.policy(), loadWork: &load, work: &work)
        guard let joint = report.joints.first, let support = report.support else { throw FoundationVerificationError.analyticCheckFailed }
        try require(report.system === system && report.fidelity == .reducedPlanarRigidTreeBalance)
        try require(abs(joint.parentOnChild.forceX+2+appliedX) < 1e-9)
        try require(abs(joint.parentOnChild.forceY-40.0/3) < 1e-9 && abs(joint.parentOnChild.momentZ) < 1e-9)
        try require(abs(joint.childOnParent.forceX-2-appliedX) < 1e-9)
        try require(abs(joint.childOnParent.forceY+40.0/3) < 1e-9 && abs(joint.childOnParent.momentZ) < 1e-9)
        try require(abs(support.supportOnRoot.forceX+2+appliedX) < 1e-9)
        try require(abs(support.supportOnRoot.forceY-70.0/3) < 1e-9 && abs(support.supportOnRoot.momentZ) < 1e-9)
        try require(joint.referencePointWorld == .zero && support.referencePointWorld == .zero)
        try require(joint.temporalMeaning == .instantaneousContinuousForce && joint.timeSeconds == 0)
        try require(report.maximumScaledOriginalGeneralizedResidual < 1e-9 && work.operations > 0 && load.consumed > 0)
        var refused = false
        do { _ = try service.recover(system, acceleration: [0], topology: .completeTree,
            outputFrame: source.snapshot.tree.worldFrame, policy: ReactionPathProbeContext.policy(), loadWork: &load, work: &work) }
        catch let error as ReactionPathError {
            guard case .originalGeneralizedResidual = error else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused)
    }

    @inline(never)
    private static func checkPlanarShiftedRawReaction(_ model: CompiledMechanicalModel) throws {
        let bodyLoad = try BodyWrenchContribution(body: PlanarPhysicalProbeModel.id(.body, "pendulum"), frame: model.tree.worldFrame,
            referencePoint: Vector3(0,0,1), wrench: SpatialWrench(torque: Vector3(0,-10,0), force: Vector3(10,0,0)), channel: .applied)
        let input = try PlanarPhysicalProbeContext.input(model, loads: [bodyLoad])
        try require(input.bodyWrenches[0].referencePoint.z == 1 && input.bodyWrenches[0].wrench.torque.y == -10)
        try checkPlanarPendulumReaction(PlanarPhysicalProbeContext.assemble(input), appliedX: 10)
    }

    @inline(never)
    private static func checkPlanarPhysicalAllocation(_ fixture: FourBarProbeModel) throws {
        let system = try GeometricProbeContext.system(fixture)
        let policy = try planarAllocationPolicy(rows: 3)
        let state = fixture.model.descriptor.initialState
        let rows = try planarAllocationRows(system, state: state, policy: policy.rows)
        let provider: any GeometricPhysicalAllocationProviding = GeometricPhysicalAllocationEvaluator()
        var work = try GeometricProbeContext.work()
        let supplied = try provider.physicalAllocation(system, state: state, supplied: rows, policy: policy, work: &work)
        let witness = try GeometricPhysicalAllocationAcceptance.validated(supplied, system: system, state: state, policy: policy, work: &work)
        try require(witness.originalRank.rank == 2 && witness.originalRank.reactionNullity == 1)
        try require(!witness.originalRank.reactionsUnique && !witness.multipliersUnique && witness.physicalWrenchesUnique)
        try require(witness.activeRowIDs == [1,2] && witness.zeroRowIDs == [3])
        try require(witness.rows.original.velocity.rowIDs == [1,2,3] && witness.rows.rows.count == 3)
        let zero = witness.rows.rows[2]
        try require(zero.isStructuralZero && zero.first.linearGradient == .zero && zero.first.angularGradient == .zero)
        try require(zero.second.linearGradient == .zero && zero.second.angularGradient == .zero)
        try require(try zero.first.linearGradient.scaled(by: 47) == .zero)
        var stale = false
        let otherTime = try KinematicState(revision: state.revision, time: 0.01, q: state.q, v: state.v, acceleration: state.acceleration)
        do throws(GeometricPhysicalAllocationError) { _ = try GeometricPhysicalAllocationAcceptance.validated(witness, system: system, state: otherTime, policy: policy, work: &work) }
        catch {
            guard case .geometry(.staleSource) = error else { throw FoundationVerificationError.unexpectedFailure }
            stale = true
        }
        try require(stale)
        try checkPlanarAllocationDuplicate(system)
    }

    @inline(never)
    private static func checkPlanarAllocationDuplicate(_ original: GeometricConstraintSystem) throws {
        guard let first = original.relations.first else { throw FoundationVerificationError.analyticCheckFailed }
        let duplicate = try GeometricRelation(kind: .coincidence, rowIDs: [11,12,13], first: first.first, second: first.second,
            target: first.target, scale: first.scale)
        var work = try GeometricProbeContext.work()
        let system = try GeometricConstraintSystem(model: original.model, layout: original.layout, relations: [first,duplicate],
            minimumPosition: original.minimumPosition, maximumPosition: original.maximumPosition,
            minimumTime: original.minimumTime, maximumTime: original.maximumTime,
            capacity: GeometricConstraintCapacity(maximumBodies: 4, maximumPositions: 3, maximumVelocities: 3,
                maximumRows: 6, maximumMetadataBytes: 32768), work: &work)
        let policy = try planarAllocationPolicy(rows: 6)
        let rows = try planarAllocationRows(system, state: original.model.descriptor.initialState, policy: policy.rows)
        var refused = false
        do throws(GeometricPhysicalAllocationError) { _ = try GeometricPhysicalAllocationEvaluator().physicalAllocation(system,
            state: original.model.descriptor.initialState, supplied: rows, policy: policy, work: &work) }
        catch {
            guard case .ambiguousPhysicalRow = error else { throw FoundationVerificationError.unexpectedFailure }
            refused = true
        }
        try require(refused)
    }

    @inline(never)
    private static func planarAllocationRows(_ system: GeometricConstraintSystem, state: KinematicState,
                                            policy: GeometricPhysicalRowPolicy) throws -> GeometricPhysicalRowWitness {
        var work = try GeometricProbeContext.work()
        let geometry: any HolonomicGeometryProviding = GeometricRelationEvaluator()
        let sample = try geometry.evaluate(system, state: state, policy: policy.evaluation, work: &work)
        return try geometry.physicalRows(system, state: state, supplied: sample, policy: policy, work: &work)
    }

    private static func planarAllocationPolicy(rows: Int) throws -> GeometricPhysicalAllocationPolicy {
        let base = try GeometricProbeContext.policy().constraints
        let evaluation = try ConstraintEvaluationPolicy(maximumCoordinates: 3, maximumRows: rows, expectedLayoutRevision: 1)
        let rank = try ConstraintSolvePolicy(evaluation: evaluation, diagonalMetric: base.diagonalMetric, energyScale: base.energyScale,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: base.rankRelativeTolerance,
            originalResidualTolerance: base.originalResidualTolerance, maximumCorrection: base.maximumCorrection,
            nonlinear: base.nonlinear, linearCapability: base.linearCapability, linearTolerance: base.linearTolerance)
        return try GeometricPhysicalAllocationPolicy(rows: GeometricPhysicalRowPolicy(evaluation: evaluation, maximumBodies: 4,
                originalComparisonTolerance: 1e-10, projectionTolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10)), rank: rank)
    }
}
