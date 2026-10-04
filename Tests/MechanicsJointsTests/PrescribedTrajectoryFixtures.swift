import Foundation
import SwiftMechanics

internal enum PrescribedTrajectoryFixtures {
    static func policy(samples: Int = 3, segments: Int = 8, metadata: Int = 20000,
                       cancelled: @escaping @Sendable () -> Bool = { false }) throws -> PrescribedTrajectoryPolicy {
        try PrescribedTrajectoryPolicy(motion: PrescribedMotionPolicy(maximumSamples: samples,
            maximumIdentifierBytes: 100, maximumMetadataBytes: metadata, isCancelled: cancelled), maximumSegments: segments)
    }
    static func work(storage: Int = 100000, operations: Int = 10000000, iterations: Int = 100) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
    }
    static func harmonic(planar: Bool = false, frame: String = "root", phase: Double = 0.3,
                         frequency: Double = 2, maximumTime: Double = 8) throws -> HarmonicPrescribedMotion {
        let rotation = try UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4)
        return try HarmonicPrescribedMotion(frame: EntityID(kind: .frame, key: frame), parentFrame: EntityID(kind: .frame, key: "world"),
            referenceTime: 0, initialPose: RigidTransform(rotation: rotation, translation: Vector3(1, 2, planar ? 0 : 3)),
            translationSine: Vector3(0.5, -0.25, planar ? 0 : 0.125), translationCosine: Vector3(0.125, 0.375, planar ? 0 : -0.25),
            rotationAxis: .unitZ, angularSine: 0.4, angularCosine: -0.2, frequency: frequency, phase: phase,
            minimumTime: -1, maximumTime: maximumTime, maximumIdentifierBytes: 100)
    }
    // Independent original coefficients, unrelated to the producer's Hermite basis.
    static func polynomial(_ time: Double, duration: Double = 1) -> (p: Double, v: Double, a: Double) {
        let t = time / duration
        if t <= 1 { return (t*t*t, 3*t*t/duration, 6*t/(duration*duration)) }
        let u = t-1
        return (1 + 3*u + 3*u*u + 2*u*u*u + 0.5*u*u*u*u,
                (3 + 6*u + 6*u*u + 2*u*u*u)/duration,
                (6 + 12*u + 6*u*u)/(duration*duration))
    }
    static func jet(_ time: Double, duration: Double = 1) throws -> PrescribedMotionJet {
        let x = polynomial(time, duration: duration)
        return try PrescribedMotionJet(displacement: Vector3(x.p, -0.5*x.p, 0), angle: 2*x.p,
            linearVelocity: Vector3(x.v, -0.5*x.v, 0), angularRate: 2*x.v,
            linearAcceleration: Vector3(x.a, -0.5*x.a, 0), angularAcceleration: 2*x.a)
    }
    static func piecewise(planar: Bool = false, frame: String = "root", duration: Double = 1) throws -> PiecewisePrescribedMotion {
        let segments = [try PrescribedMotionSegment(startTime: 0, endTime: duration, start: jet(0, duration: duration), end: jet(duration, duration: duration)),
            try PrescribedMotionSegment(startTime: duration, endTime: 2*duration, start: jet(duration, duration: duration), end: jet(2*duration, duration: duration))]
        let rotation = try UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4)
        var work = try work()
        return try PiecewisePrescribedMotion(frame: EntityID(kind: .frame, key: frame), parentFrame: EntityID(kind: .frame, key: "world"),
            initialPose: RigidTransform(rotation: rotation, translation: Vector3(1, 2, planar ? 0 : 3)), rotationAxis: .unitZ,
            segments: segments, policy: policy(), work: &work)
    }
    static func anchor(_ trajectories: [PrescribedTrajectory], policy: PrescribedTrajectoryPolicy? = nil) throws -> PrescribedTrajectoryProgram {
        var work = try work()
        return try PrescribedTrajectoryProgram(trajectories: trajectories, policy: policy ?? self.policy(), work: &work)
    }
    static func base(_ trajectory: PrescribedTrajectory, planar: Bool = false) throws -> PrescribedBaseTrajectoryProgram {
        var work = try work()
        return try PrescribedBaseTrajectoryProgram(trajectory: trajectory, layout: planar ? .planarFloating : .spatialFloating,
            policy: policy(), work: &work)
    }
    static func harmonicOracle(_ time: Double, phase: Double = 0.3) -> (p: [Double], v: [Double], a: [Double], angle: Double, omega: Double, alpha: Double) {
        let sine = sin(phase + 2*time), cosine = cos(phase + 2*time)
        let ds = sine-sin(phase), dc = cosine-cos(phase)
        let s = [0.5, -0.25, 0.125], c = [0.125, 0.375, -0.25]
        var p = [1.0,2.0,3.0], v = [Double](), a = [Double]()
        for i in 0..<3 { p[i] += s[i]*ds+c[i]*dc; v.append(2*(s[i]*cosine-c[i]*sine)); a.append(-4*(s[i]*sine+c[i]*cosine)) }
        return (p,v,a,0.4*ds-0.2*dc,2*(0.4*cosine+0.2*sine),-4*(0.4*sine-0.2*cosine))
    }
}
