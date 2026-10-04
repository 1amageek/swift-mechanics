import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyPlanarClosedLoopReactions() throws {
        let fixture = try PlanarLoopProbeModel()
        let context = try PlanarLoopProbeContext(fixture: fixture)
        try checkPlanarLoopReport(context.recover(), context: context, multiplier: 2.0/3)
        try checkPlanarLoopNormalization(fixture)
        try checkPlanarLoopRefusals(context)
        print("AF25 planar closed-loop physical uniqueness, original force/support balance and typed refusals passed.")
    }

    @inline(never)
    private static func checkPlanarLoopReport(_ report: PlanarClosedLoopReactionReport,
                                             context: PlanarLoopProbeContext, multiplier: Double) throws {
        let fixture = context.fixture
        let accepted = context.motion.motion
        try require(abs(accepted.values[fixture.crankIndex]-1.0/3) < 1e-9)
        try require(abs(accepted.values[fixture.couplerIndex]+1.0/3) < 1e-9)
        try require(abs(accepted.values[fixture.rockerIndex]-1.0/3) < 1e-9)
        try require(report.source.motion === context.motion && report.source.dynamics === context.dynamics)
        try require(report.originalRank.rank == 2 && report.originalRank.reactionNullity == 1)
        try require(report.physicalWrenchesUnique && !report.multipliersUnique)
        try require(!report.originalRank.reactionsUnique && report.originalRows.rows.count == 3)
        try require(report.loops.map { $0.rowID } == [11, 12, 13])
        guard let x = report.loops.first, let z = report.loops.last,
              let support = report.tree.support else { throw FoundationVerificationError.analyticCheckFailed }
        try require(abs(x.multiplierJoules-multiplier) < 1e-9)
        try require(abs(report.loops[1].multiplierJoules) < 1e-9 && z.isStructuralZero)
        try require(abs(x.secondOnFirst.forceX-1.0/3) < 1e-9 && abs(x.secondOnFirst.forceY) < 1e-9)
        try require(abs(x.firstOnSecond.forceX+1.0/3) < 1e-9 && abs(x.firstOnSecond.forceY) < 1e-9)
        try require(abs(x.secondOnFirst.momentZ) < 1e-9 && abs(x.firstOnSecond.momentZ) < 1e-9)
        try require(z.secondOnFirst.forceX == 0 && z.secondOnFirst.forceY == 0 && z.secondOnFirst.momentZ == 0)
        try require(abs(x.firstEndpointWorld.x-2) < 1e-9 && abs(x.firstEndpointWorld.y-1) < 1e-9)
        try require(abs(x.secondEndpointWorld.x-2) < 1e-9 && abs(x.secondEndpointWorld.y-1) < 1e-9)
        try require(x.frame == fixture.model.tree.worldFrame && x.referencePointWorld == x.firstEndpointWorld)
        try require(report.tree.joints.count == 3)
        for cut in report.tree.joints {
            let expected = cut.joint == fixture.rockerJoint ? 1.0/3 : -2.0/3
            try require(abs(cut.parentOnChild.forceX-expected) < 1e-9)
            try require(abs(cut.parentOnChild.forceY) < 1e-9 && abs(cut.parentOnChild.momentZ) < 1e-9)
            try require(abs(cut.childOnParent.forceX+expected) < 1e-9)
        }
        try require(abs(support.supportOnRoot.forceX+1.0/3) < 1e-9)
        try require(abs(support.supportOnRoot.forceY) < 1e-9 && abs(support.supportOnRoot.momentZ) < 1e-9)
        try require(report.maximumOriginalPositionResidual < 1e-9)
        try require(report.maximumOriginalVelocityResidual < 1e-9 && report.maximumOriginalAccelerationResidual < 1e-9)
        try require(report.tree.maximumScaledOriginalGeneralizedResidual < 1e-9)
        try require(report.numericalWork.operations > 0 && report.temporalMeaning == .instantaneousContinuousForce)
    }

    @inline(never)
    private static func checkPlanarLoopNormalization(_ fixture: PlanarLoopProbeModel) throws {
        let context = try PlanarLoopProbeContext(fixture: fixture, scale: 1)
        try checkPlanarLoopReport(context.recover(), context: context, multiplier: 1.0/3)
    }

    @inline(never)
    private static func checkPlanarLoopRefusals(_ context: PlanarLoopProbeContext) throws {
        let service: any PlanarClosedLoopReactionRecovering = PlanarClosedLoopReactionRecovery()
        let policy = try PlanarLoopProbeContext.policy()
        let state = context.fixture.model.descriptor.initialState
        let duplicate = try PlanarLoopProbeContext.geometry(context.fixture, scale: 2, duplicate: true)
        let duplicateRows = try PlanarLoopProbeContext.rows(duplicate, state: state)
        let duplicateMotion = try PlanarLoopProbeContext.solve(context.dynamics, rows: duplicateRows)
        let duplicateInput = PlanarClosedLoopReactionInput(motion: duplicateMotion, geometry: duplicate, state: state,
            allocation: context.allocation, originalDrive: [0, 0, 0], topology: .completeTreeAndDeclaredRows)
        var work = try GeometricProbeContext.work(), load = try PlanarLoopProbeContext.loadWork()
        var ambiguous = false
        do throws(ClosedLoopReactionError) {
            _ = try service.recover(duplicateInput, outputFrame: context.fixture.model.tree.worldFrame,
                policy: policy, loadWork: &load, work: &work)
        } catch {
            guard case .ambiguousAllocation = error else { throw error }
            ambiguous = true
        }
        let unallocated = PlanarClosedLoopReactionInput(motion: context.motion, geometry: context.geometry, state: state,
            allocation: context.allocation, originalDrive: [1, 0, 0], topology: .completeTreeAndDeclaredRows)
        var refused = false
        do throws(ClosedLoopReactionError) {
            _ = try service.recover(unallocated, outputFrame: context.fixture.model.tree.worldFrame,
                policy: policy, loadWork: &load, work: &work)
        } catch {
            guard case .unallocatableGeneralizedLoad = error else { throw error }
            refused = true
        }
        try require(ambiguous && refused)
    }
}
