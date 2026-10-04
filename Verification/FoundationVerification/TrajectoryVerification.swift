import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyTrajectoryLower() throws {
        let fixture = try TrajectoryProbeModel()
        for time in [0.0, 0.35, 1.0, 2.0] {
            try verifyTrajectorySample(fixture, time: time, harmonic: true)
            try verifyTrajectorySample(fixture, time: time, harmonic: false)
        }
        for time in [0.999999, 1.000001] {
            try verifyTrajectorySample(fixture, time: time, harmonic: false)
        }
        try verifyTrajectoryBoundaries(fixture)
        try verifyTrajectoryRefusals(fixture)
        print("AF26 trajectories: harmonic and C2 jets, noncommuting qdot, unwrapped angle and original knots passed")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTrajectorySample(_ fixture: TrajectoryProbeModel, time: Double,
                                               harmonic: Bool) throws {
        let base = harmonic ? fixture.harmonicBase : fixture.piecewiseBase
        let anchors = harmonic ? fixture.harmonicAnchors : fixture.piecewiseAnchors
        let oracle = harmonic ? TrajectoryProbeOracle(harmonicAt: time) : TrajectoryProbeOracle(piecewiseAt: time)
        var work = try GeometricProbeContext.work()
        let service: any PrescribedBaseTrajectorySampling = AnalyticPrescribedBaseTrajectorySampler()
        let sample = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(base, time: time,
            policy: fixture.policy, sampler: service, work: &work)
        try requireTrajectoryValues(sample.q, oracle.q)
        try requireTrajectoryValues(sample.v, oracle.v)
        try requireTrajectoryValues(sample.a, oracle.a)
        try requireTrajectoryValues(sample.coordinateRate, oracle.coordinateRate)
        try require(sample.metadata == base.metadata && sample.time.bitPattern == time.bitPattern)
        if !harmonic && time == 2 { try require(sample.q[2] > 6.28) }
        let anchorService: any PrescribedTrajectorySampling = AnalyticPrescribedTrajectorySampler()
        let frameSample = try OriginalPrescribedTrajectoryAcceptance.sealedMotion(anchors, time: time,
            policy: fixture.policy, sampler: anchorService, work: &work)
        try require(frameSample.anchors.count == 1 && frameSample.metadata == anchors.metadata)
        let frame = frameSample.anchors[0]
        try require(frame.frame == sample.frame && frame.time.bitPattern == time.bitPattern)
        try require(abs(frame.motion.velocity.angular.z-oracle.angularRate) < 1e-10)
        try require(abs(frame.motion.acceleration.angular.z-oracle.angularAcceleration) < 1e-10)
        try require(abs(frame.motion.velocity.linear.y-oracle.v[1]) < 1e-10)
        try require(abs(frame.motion.acceleration.linear.y-oracle.a[1]) < 1e-10)
    }

    private static func requireTrajectoryValues(_ actual: [Double], _ expected: [Double]) throws {
        try require(actual.count == expected.count)
        for index in actual.indices {
            try require(abs(actual[index]-expected[index]) < 1e-10*(1+abs(expected[index])))
        }
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTrajectoryBoundaries(_ fixture: TrajectoryProbeModel) throws {
        var work = try GeometricProbeContext.work()
        let query: any PrescribedTrajectoryBoundaryQuerying = PrescribedTrajectoryBoundaryQuery()
        let seam = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(fixture.piecewiseBase,
            after: 0.25, through: 1.5, policy: fixture.policy, query: query, work: &work)
        try require(seam?.bitPattern == Double(1).bitPattern)
        let consumed = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(fixture.piecewiseBase,
            after: 1, through: 2, policy: fixture.policy, query: query, work: &work)
        try require(consumed == nil)
        let anchor = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBoundary(fixture.piecewiseAnchors,
            after: 0, through: 1, policy: fixture.policy, query: query, work: &work)
        try require(anchor?.bitPattern == Double(1).bitPattern)
        let smooth = try OriginalPrescribedTrajectoryBoundaryAcceptance.nextBaseBoundary(fixture.harmonicBase,
            after: 0, through: 2, policy: fixture.policy, query: query, work: &work)
        try require(smooth == nil)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyTrajectoryRefusals(_ fixture: TrajectoryProbeModel) throws {
        var discontinuity = false
        do {
            _ = try TrajectoryProbeModel(seamAngularAcceleration: 7)
        } catch PrescribedMotionError.unsupportedDiscontinuity(let time, .acceleration) {
            discontinuity = time.bitPattern == Double(1).bitPattern
        }
        try require(discontinuity)
        var outside = false, work = try GeometricProbeContext.work()
        do {
            _ = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(fixture.harmonicBase, time: 2.1,
                policy: fixture.policy, sampler: AnalyticPrescribedBaseTrajectorySampler(), work: &work)
        } catch PrescribedMotionError.outsideDomain { outside = true }
        try require(outside)
    }
}
