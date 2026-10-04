import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyClosedLoopReactions() throws {
        let fixture = try ClosedLoopProbeModel()
        let context = try ClosedLoopProbeContext(fixture: fixture)
        try checkClosedLoopSlider(context, scale: 4, multiplier: 48)
        try checkClosedLoopNormalization(fixture)
        try checkClosedLoopOffsets()
        try checkClosedLoopAmbiguity(fixture)
        try checkClosedLoopRefusals(context)
        print("Closed-loop reaction verification passed: identified continuous slider forces, normalization, spatial support moments and source/ambiguity/temporal refusal.")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopSlider(_ context: ClosedLoopProbeContext, scale: Double, multiplier: Double) throws {
        let report = try context.recover()
        try checkClosedLoopSliderReport(report, context: context, scale: scale, multiplier: multiplier)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopSliderReport(_ report: ClosedLoopReactionReport, context: ClosedLoopProbeContext,
                                                  scale: Double, multiplier: Double) throws {
        guard report.loops.count == 1, let row = report.loops.first, let support = report.tree.support else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let first = context.fixture.firstIndex, second = context.fixture.secondIndex
        try require(abs(context.motion.values[first] - 2) < 1e-9 && abs(context.motion.values[second] - 2) < 1e-9)
        try require(row.rowID == 91 && row.normalizationScale == scale && abs(row.multiplierJoules - multiplier) < 1e-9)
        try require(row.firstBody == context.fixture.first && row.secondBody == context.fixture.second)
        try checkClosedLoopVector(row.secondOnFirst.force, x: -6, y: 0, z: 0)
        try checkClosedLoopVector(row.firstOnSecond.force, x: 6, y: 0, z: 0)
        try checkClosedLoopVector(row.secondOnFirst.torque, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(row.firstOnSecond.torque, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(row.firstEndpointWorld, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(row.secondEndpointWorld, x: 2, y: 0, z: 0)
        try require(row.referencePointWorld == row.firstEndpointWorld && row.referencePoint == row.referencePointWorld)
        try require(row.frame == context.fixture.model.tree.worldFrame && row.timeSeconds == 0 && row.revision == 1)
        try require(row.temporalMeaning == .instantaneousContinuousForce && report.temporalMeaning == .instantaneousContinuousForce)
        try require(report.originalRank.reactionsUnique && report.originalRows.rows.count == 1)
        try require(report.topologyAssumption == .completeTreeAndDeclaredRows)
        // Independent Newton balances: each identified mass accelerates at 2 m/s².
        try require(abs(2 * context.motion.values[first] - (10 + row.secondOnFirst.force.x)) < 1e-9)
        try require(abs(3 * context.motion.values[second] - row.firstOnSecond.force.x) < 1e-9)
        try require(report.tree.joints.count == 2)
        for cut in report.tree.joints {
            try checkClosedLoopVector(cut.parentOnChild.force, x: 0, y: 0, z: 0)
            try checkClosedLoopVector(cut.parentOnChild.torque, x: 0, y: 0, z: 0)
        }
        try checkClosedLoopVector(support.supportOnRoot.force, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(support.supportOnRoot.torque, x: 0, y: 0, z: 0)
        try checkClosedLoopOriginalAcceptance(report)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopNormalization(_ fixture: ClosedLoopProbeModel) throws {
        let context = try ClosedLoopProbeContext(fixture: fixture, scale: 1)
        // The multiplier changes from 48 to 3 J; the independent physical force stays 6 N.
        try checkClosedLoopSlider(context, scale: 1, multiplier: 3)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopOffsets() throws {
        let context = try ClosedLoopProbeContext(fixture: ClosedLoopProbeModel(offset: true))
        try checkClosedLoopWorldOffsets(context.recover(), context: context)
        let frame = try EntityID(kind: .frame, key: context.fixture.first.key + "-frame")
        try checkClosedLoopRotatedOffsets(context.recover(frame: frame), frame: frame)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopWorldOffsets(_ report: ClosedLoopReactionReport, context: ClosedLoopProbeContext) throws {
        guard let loop = report.loops.first,
              let first = report.tree.joints.first(where: { $0.joint == context.fixture.firstJoint }),
              let second = report.tree.joints.first(where: { $0.joint == context.fixture.secondJoint }),
              let support = report.tree.support else { throw FoundationVerificationError.analyticCheckFailed }
        try checkClosedLoopVector(loop.firstEndpointWorld, x: 0, y: 1, z: 0)
        try checkClosedLoopVector(loop.secondEndpointWorld, x: 2, y: 1, z: 0)
        try checkClosedLoopVector(loop.referencePointWorld, x: 0, y: 1, z: 0)
        try checkClosedLoopVector(loop.secondOnFirst.force, x: -6, y: 0, z: 0)
        try checkClosedLoopOpposites(loop.secondOnFirst, loop.firstOnSecond)
        // F=(10,0,5) applied at Y gives (5,0,-10) about first origin;
        // the loop force -6 X at Y adds +6 Z, so the guide supplies (-5,0,4).
        try checkClosedLoopVector(first.referencePointWorld, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(first.parentOnChild.force, x: 0, y: 0, z: -5)
        try checkClosedLoopVector(first.parentOnChild.torque, x: -5, y: 0, z: 4)
        try checkClosedLoopVector(second.referencePointWorld, x: 2, y: 0, z: 0)
        try checkClosedLoopVector(second.parentOnChild.force, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(second.parentOnChild.torque, x: 0, y: 0, z: 6)
        try checkClosedLoopVector(support.referencePointWorld, x: 0, y: 0, z: 0)
        try checkClosedLoopVector(support.supportOnRoot.force, x: 0, y: 0, z: -5)
        try checkClosedLoopVector(support.supportOnRoot.torque, x: -5, y: 0, z: 10)
        for cut in report.tree.joints {
            try checkClosedLoopOpposites(cut.parentOnChild, cut.childOnParent)
            try require(cut.frame == context.fixture.model.tree.worldFrame && cut.timeSeconds == 0 && cut.revision == 1)
            try require(cut.temporalMeaning == .instantaneousContinuousForce)
        }
        try checkClosedLoopOpposites(support.supportOnRoot, support.rootOnSupport)
        try checkClosedLoopOriginalAcceptance(report)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopRotatedOffsets(_ report: ClosedLoopReactionReport, frame: EntityID) throws {
        guard let loop = report.loops.first, let support = report.tree.support else { throw FoundationVerificationError.analyticCheckFailed }
        try require(loop.frame == frame && support.frame == frame)
        try checkClosedLoopVector(loop.secondOnFirst.force, x: 0, y: 6, z: 0)
        try checkClosedLoopVector(loop.referencePoint, x: 1, y: 0, z: 0)
        try checkClosedLoopVector(loop.referencePointWorld, x: 0, y: 1, z: 0)
        try checkClosedLoopVector(support.supportOnRoot.force, x: 0, y: 0, z: -5)
        try checkClosedLoopVector(support.supportOnRoot.torque, x: 0, y: 5, z: 10)
        try checkClosedLoopOpposites(loop.secondOnFirst, loop.firstOnSecond)
        for cut in report.tree.joints { try checkClosedLoopOpposites(cut.parentOnChild, cut.childOnParent) }
        try checkClosedLoopOpposites(support.supportOnRoot, support.rootOnSupport)
        try checkClosedLoopOriginalAcceptance(report)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopAmbiguity(_ fixture: ClosedLoopProbeModel) throws {
        let context = try ClosedLoopProbeContext(fixture: fixture, duplicate: true)
        try require(context.motion.rowIDs == [91, 92] && context.motion.rank.reactionNullity == 1)
        try require(context.physicalRows.rows.count == 2 && context.motion.rowMultipliers[1] == 0)
        try expectClosedLoopRefusal(context.input()) {
            if case .ambiguousAllocation(nullity: 1) = $0 { true } else { false }
        }
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func checkClosedLoopRefusals(_ context: ClosedLoopProbeContext) throws {
        try expectClosedLoopRefusal(context.input(drive: [10, 0])) {
            if case .unallocatableGeneralizedLoad = $0 { true } else { false }
        }
        let stronger = try ClosedLoopProbeContext.assemble(context.fixture, force: 11)
        try expectClosedLoopRefusal(context.input(dynamics: stronger)) {
            if case .tree(.originalGeneralizedResidual) = $0 { true } else { false }
        }
        let state = context.fixture.model.descriptor.initialState
        let later = try KinematicState(revision: state.revision, time: 0.25, q: state.q, v: state.v, acceleration: state.acceleration)
        try expectClosedLoopRefusal(context.input(state: later)) {
            if case .staleSource = $0 { true } else { false }
        }
        let impulse = try ClosedLoopProbeContext.solve(context.dynamics, rows: context.physicalRows, impulse: true)
        try require(impulse.temporalMeaning == .instantaneousVelocityImpulse)
        try expectClosedLoopRefusal(context.input(motion: impulse)) {
            if case .unsupportedTemporalMeaning = $0 { true } else { false }
        }
        try expectClosedLoopRefusal(context.input(topology: .unrepresentedConnections)) {
            if case .unrepresentedConnections = $0 { true } else { false }
        }
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func expectClosedLoopRefusal(_ input: ClosedLoopReactionInput, matching: (ClosedLoopReactionError) -> Bool) throws {
        let policy = try ClosedLoopProbeContext.policy()
        var work = try MechanismProbeContext.work(), load = try ClosedLoopProbeContext.loadWork(), refused = false
        let service: any ClosedLoopReactionRecovering = ClosedLoopReactionRecovery()
        do throws(ClosedLoopReactionError) {
            _ = try service.recover(input, outputFrame: input.geometry.model.tree.worldFrame,
                                   policy: policy, loadWork: &load, work: &work)
        } catch {
            try require(matching(error))
            refused = true
        }
        try require(refused)
    }

    @inline(never)
    private static func checkClosedLoopVector(_ actual: Vector3, x: Double, y: Double, z: Double) throws {
        try require(abs(actual.x - x) < 1e-9 && abs(actual.y - y) < 1e-9 && abs(actual.z - z) < 1e-9)
    }

    @inline(never)
    private static func checkClosedLoopOpposites(_ first: SpatialWrench, _ second: SpatialWrench) throws {
        try checkClosedLoopVector(first.force.adding(second.force), x: 0, y: 0, z: 0)
        try checkClosedLoopVector(first.torque.adding(second.torque), x: 0, y: 0, z: 0)
    }

    @inline(never)
    private static func checkClosedLoopOriginalAcceptance(_ report: ClosedLoopReactionReport) throws {
        try require(report.maximumOriginalPositionResidual < 1e-9 && report.maximumOriginalVelocityResidual < 1e-9)
        try require(report.maximumOriginalAccelerationResidual < 1e-9 && report.tree.maximumScaledOriginalGeneralizedResidual < 1e-9)
        try require(report.numericalWork.operations > 0)
    }
}
