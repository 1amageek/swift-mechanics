import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension FoundationVerification {
    @inline(never)
    static func verifyPrescribedBaseLower() throws {
        try checkPrescribedBaseSample(planar: false)
        try checkPrescribedBaseSample(planar: true)
        try checkActiveCoordinateRanks()
        print("AF25 prescribed-base sampling and original-layout active rank passed.")
    }

    @inline(never)
    private static func checkPrescribedBaseSample(planar: Bool) throws {
        let policy = try prescribedBasePolicy()
        var work = try GeometricProbeContext.work()
        let law = try prescribedBaseLaw(planar: planar)
        let program = try PrescribedBaseMotionProgram(law: law,
            layout: planar ? .planarFloating : .spatialFloating, policy: policy, work: &work)
        let sampler: any PrescribedBaseMotionSampling = AnalyticPrescribedBaseMotionSampler()
        let t = 0.7
        let sample = try OriginalPrescribedBaseMotionAcceptance.sealedBaseMotion(program,
            time: t, policy: policy, sampler: sampler, work: &work)
        let canonical = try OriginalPrescribedBaseMotionAcceptance.validated(sample,
            program: program, time: t, policy: policy, work: &work)
        try require(canonical.q == sample.q && canonical.v == sample.v && canonical.a == sample.a)
        try require(canonical.coordinateRate == sample.coordinateRate && sample.frame == law.frame)
        try require(sample.worldFrame == law.parentFrame && sample.time == t && work.operations > 0)
        let angle = 0.2*t + 0.15*t*t, rate = 0.2 + 0.3*t
        let expectedPosition = [1+0.4*t+0.15*t*t, 2-0.2*t+0.1*t*t]
        let expectedVelocity = [0.4+0.3*t, -0.2+0.2*t]
        for i in 0..<2 {
            try require(abs(sample.q[i]-expectedPosition[i]) < 1e-12)
            try require(abs(sample.v[i]-expectedVelocity[i]) < 1e-12)
        }
        if planar {
            try require(sample.q.count == 3 && sample.v.count == 3 && sample.a.count == 3)
            try require(abs(sample.q[2]-0.4-angle) < 1e-12 && abs(sample.v[2]-rate) < 1e-12)
            try require(sample.a == [0.3, 0.2, 0.3])
            try require(sample.coordinateRate == sample.v)
        } else {
            let c = cos(angle/2), s = sin(angle/2), cr = cos(0.2), sr = sin(0.2)
            let q = [c*cr, c*sr, s*sr, s*cr]
            let qdot = [-0.5*rate*s*cr, -0.5*rate*s*sr, 0.5*rate*c*sr, 0.5*rate*c*cr]
            try require(sample.q.count == 7 && sample.v.count == 6 && sample.a.count == 6)
            try require(abs(sample.q[2]-(3+0.1*t-0.05*t*t)) < 1e-12)
            try require(abs(sample.v[2]-(0.1-0.1*t)) < 1e-12)
            for i in 0..<4 {
                try require(abs(sample.q[3+i]-q[i]) < 1e-12)
                try require(abs(sample.coordinateRate[3+i]-qdot[i]) < 1e-12)
            }
            try require(abs(sample.v[3]) < 1e-12 && abs(sample.v[4]-sin(0.4)*rate) < 1e-12)
            try require(abs(sample.v[5]-cos(0.4)*rate) < 1e-12)
            try require(abs(sample.a[3]) < 1e-12 && abs(sample.a[4]-sin(0.4)*0.3) < 1e-12)
            try require(abs(sample.a[5]-cos(0.4)*0.3) < 1e-12)
        }
        try require(abs(sample.motion.velocity.angular.z-rate) < 1e-12)
        try require(abs(sample.motion.acceleration.angular.z-0.3) < 1e-12)
        var stale = false, outside = false, changedLaw = false
        do throws(PrescribedMotionError) { _ = try OriginalPrescribedBaseMotionAcceptance.validated(sample,
            program: program, time: t+0.01, policy: policy, work: &work) }
        catch { guard case .staleSource = error else { throw FoundationVerificationError.unexpectedFailure }; stale = true }
        do throws(PrescribedMotionError) { _ = try sampler.sampleBase(program, time: 3, policy: policy, work: &work) }
        catch { guard case .outsideDomain = error else { throw FoundationVerificationError.unexpectedFailure }; outside = true }
        let other = try PrescribedBaseMotionProgram(law: prescribedBaseLaw(planar: planar, acceleration: 0.4),
            layout: program.layout, policy: policy, work: &work)
        do throws(PrescribedMotionError) { _ = try OriginalPrescribedBaseMotionAcceptance.validated(sample,
            program: other, time: t, policy: policy, work: &work) }
        catch { guard case .staleSource = error else { throw FoundationVerificationError.unexpectedFailure }; changedLaw = true }
        try require(stale && outside && changedLaw)
    }

    @inline(never)
    private static func prescribedBaseLaw(planar: Bool, acceleration: Double = 0.3) throws -> AnalyticPrescribedMotion {
        let root = try EntityID(kind: .frame, key: "af25-prescribed-root")
        let world = try EntityID(kind: .frame, key: "af25-prescribed-world")
        let rotation = try UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4)
        return try AnalyticPrescribedMotion(frame: root, parentFrame: world, referenceTime: 0,
            initialPose: RigidTransform(rotation: rotation, translation: Vector3(1, 2, planar ? 0 : 3)),
            translationRate: Vector3(0.4, -0.2, planar ? 0 : 0.1),
            translationAcceleration: Vector3(0.3, 0.2, planar ? 0 : -0.1), rotationAxis: .unitZ,
            angularRate: 0.2, angularAcceleration: acceleration, minimumTime: 0, maximumTime: 2,
            maximumIdentifierBytes: 1024)
    }

    private static func prescribedBasePolicy() throws -> PrescribedMotionPolicy {
        try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 1024, maximumMetadataBytes: 8192)
    }

    @inline(never)
    private static func checkActiveCoordinateRanks() throws {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [1,2,3,4,5,6],
            dimensions: [.length,.length,.length,.angle,.angle,.angle], scales: [2,3,4,5,6,7], timeScale: 2, revision: 1)
        let sample = VelocityConstraintSample(layout: layout, rowIDs: [31,32,33],
            rows: [1,0,0,1,0,0, 0,1,0,0,2,0, 0,0,0,0,0,0],
            drift: [0.1,0.2,0], accelerationBias: [0.3,0.4,0], isIntegrable: true)
        let ranker: any ActiveCoordinateRankAnalyzing = WeightedConstraintAssembler()
        let policy = try activeRankPolicy()
        var work = try GeometricProbeContext.work()
        let active = try ranker.rank(sample, activeCoordinates: [3,4,5], policy: policy, work: &work)
        try require(active.rank.rank == 2 && active.rank.reactionNullity == 1)
        try require(active.sample.rows == sample.rows && active.sample.layout.coordinateIDs == layout.coordinateIDs)
        try require(active.originalRowCount == 3 && active.originalCoordinateCount == 6 && active.activeCoordinateCount == 3)
        let noDynamic = try ranker.rank(sample, activeCoordinates: [], policy: policy, work: &work)
        try require(noDynamic.rank.rank == 0 && noDynamic.rank.reactionNullity == 3)
        try require(noDynamic.rank.dependentRowIDs == sample.rowIDs && noDynamic.sample.rows == sample.rows)
        let empty = VelocityConstraintSample(layout: layout, rowIDs: [], rows: [], drift: [], accelerationBias: [], isIntegrable: true)
        let noGeometry = try ranker.rank(empty, activeCoordinates: [], policy: policy, work: &work)
        try require(noGeometry.rank.rank == 0 && noGeometry.rank.reactionNullity == 0 && noGeometry.originalCoordinateCount == 6)
        var invalid = false
        do throws(ConstraintError) { _ = try ranker.rank(sample, activeCoordinates: [3,3], policy: policy, work: &work) }
        catch {
            guard case .invalidInput = error else { throw FoundationVerificationError.unexpectedFailure }
            invalid = true
        }
        try require(invalid && work.operations > 0)
    }

    private static func activeRankPolicy() throws -> ConstraintSolvePolicy {
        let base = try MechanismProbeContext.policy().constraints
        return try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 6, maximumRows: 6,
                expectedLayoutRevision: 1), diagonalMetric: [1,2,3,4,5,6], energyScale: 7,
            rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10, originalResidualTolerance: 1e-9,
            maximumCorrection: 1, nonlinear: base.nonlinear, linearCapability: base.linearCapability,
            linearTolerance: base.linearTolerance)
    }
}
