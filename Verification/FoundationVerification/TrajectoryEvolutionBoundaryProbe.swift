import SwiftMechanics
import Synchronization

/// Records the actual accepted-time boundary calls without changing original query authority or work.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class TrajectoryEvolutionBoundaryProbe: PrescribedTrajectoryBoundaryQuerying, Sendable {
    private let observation = Mutex<(atKnot: Bool, calls: Int)>((false, 0))

    var observedAcceptedKnot: Bool { observation.withLock { $0.atKnot } }
    var calls: Int { observation.withLock { $0.calls } }

    private func observe(_ time: Double) throws(PrescribedMotionError) {
        let admitted = observation.withLock {
            guard $0.calls < 1000 else { return false }
            $0.calls += 1
            $0.atKnot = $0.atKnot || time.bitPattern == Double(1).bitPattern
            return true
        }
        guard admitted else { throw .capacityExceeded }
    }

    func nextBoundary(_ program: PrescribedTrajectoryProgram, after time: Double, through limit: Double,
                      policy: PrescribedTrajectoryPolicy, work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try observe(time)
        return try PrescribedTrajectoryBoundaryQuery().nextBoundary(program, after: time, through: limit, policy: policy, work: &work)
    }

    func nextBaseBoundary(_ program: PrescribedBaseTrajectoryProgram, after time: Double, through limit: Double,
                          policy: PrescribedTrajectoryPolicy, work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try observe(time)
        return try PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(program, after: time, through: limit, policy: policy, work: &work)
    }
}
