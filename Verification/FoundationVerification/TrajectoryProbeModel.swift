import SwiftMechanics

/// Bounded public trajectory programs; each construction owns a separate work ledger.
struct TrajectoryProbeModel: Sendable {
    let policy: PrescribedTrajectoryPolicy
    let harmonicBase: PrescribedBaseTrajectoryProgram
    let harmonicAnchors: PrescribedTrajectoryProgram
    let piecewiseBase: PrescribedBaseTrajectoryProgram
    let piecewiseAnchors: PrescribedTrajectoryProgram

    @inline(never)
    init(seamAngularAcceleration: Double = 6) throws {
        policy = try PrescribedTrajectoryPolicy(motion: PrescribedMotionPolicy(maximumSamples: 2,
            maximumIdentifierBytes: 1024, maximumMetadataBytes: 32768), maximumSegments: 2)
        let harmonic = try Self.harmonic()
        harmonicBase = try Self.base(.harmonic(harmonic), layout: .spatialFloating, policy: policy)
        harmonicAnchors = try Self.anchors(.harmonic(harmonic), policy: policy)
        let piecewise = try Self.piecewise(policy: policy, seamAngularAcceleration: seamAngularAcceleration)
        piecewiseBase = try Self.base(.piecewise(piecewise), layout: .planarFloating, policy: policy)
        piecewiseAnchors = try Self.anchors(.piecewise(piecewise), policy: policy)
    }

    @inline(never)
    private static func harmonic() throws -> HarmonicPrescribedMotion {
        try HarmonicPrescribedMotion(frame: EntityID(kind: .frame, key: "af26-harmonic-frame"),
            parentFrame: EntityID(kind: .frame, key: "af26-trajectory-parent"), referenceTime: 0,
            initialPose: RigidTransform(rotation: UnitQuaternion(axis: .unitX, angle: 0.4),
                translation: Vector3(1, 2, 3)),
            translationSine: Vector3(0.3, -0.2, 0.1), translationCosine: Vector3(0.1, 0.2, -0.1),
            rotationAxis: .unitZ, angularSine: 0.4, angularCosine: 0.2, frequency: 2, phase: 0.3,
            minimumTime: 0, maximumTime: 2, maximumIdentifierBytes: 1024)
    }

    @inline(never)
    private static func piecewise(policy: PrescribedTrajectoryPolicy,
                                  seamAngularAcceleration: Double) throws -> PiecewisePrescribedMotion {
        let start = try jet(displacement: 0, rate: 0, acceleration: 0)
        let seam = try jet(displacement: 1, rate: 3, acceleration: 6)
        let following = try PrescribedMotionJet(displacement: Vector3(0, 0.125, 0), angle: 1,
            linearVelocity: Vector3(0, 0.375, 0), angularRate: 3,
            linearAcceleration: Vector3(0, 0.75, 0), angularAcceleration: seamAngularAcceleration)
        let end = try jet(displacement: 9, rate: 15, acceleration: 18)
        let segments = [try PrescribedMotionSegment(startTime: 0, endTime: 1, start: start, end: seam),
            try PrescribedMotionSegment(startTime: 1, endTime: 2, start: following, end: end)]
        var work = try Self.work()
        return try PiecewisePrescribedMotion(frame: EntityID(kind: .frame, key: "af26-piecewise-frame"),
            parentFrame: EntityID(kind: .frame, key: "af26-trajectory-parent"),
            initialPose: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: 0.4),
                translation: Vector3(1, 2, 0)), rotationAxis: .unitZ,
            segments: segments, policy: policy, work: &work)
    }

    private static func jet(displacement: Double, rate: Double,
                            acceleration: Double) throws -> PrescribedMotionJet {
        try PrescribedMotionJet(displacement: Vector3(0, 0.125*displacement, 0), angle: displacement,
            linearVelocity: Vector3(0, 0.125*rate, 0), angularRate: rate,
            linearAcceleration: Vector3(0, 0.125*acceleration, 0), angularAcceleration: acceleration)
    }

    @inline(never)
    private static func base(_ trajectory: PrescribedTrajectory, layout: BaseLayout,
                             policy: PrescribedTrajectoryPolicy) throws -> PrescribedBaseTrajectoryProgram {
        var work = try Self.work()
        return try PrescribedBaseTrajectoryProgram(trajectory: trajectory, layout: layout,
            policy: policy, work: &work)
    }

    @inline(never)
    private static func anchors(_ trajectory: PrescribedTrajectory,
                                policy: PrescribedTrajectoryPolicy) throws -> PrescribedTrajectoryProgram {
        var work = try Self.work()
        return try PrescribedTrajectoryProgram(trajectories: [trajectory], policy: policy, work: &work)
    }

    private static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 1_000_000,
            arithmeticOperations: 20_000_000, iterations: 1000))
    }
}
