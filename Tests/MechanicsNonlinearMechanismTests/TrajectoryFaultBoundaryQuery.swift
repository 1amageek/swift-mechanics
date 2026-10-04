import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class TrajectoryFaultBoundaryQuery: PrescribedTrajectoryBoundaryQuerying, Sendable {
    enum Fault:Sendable { case none,wrongNil,late,resetFailure,cancel,unknown }
    let fault:Fault
    private let times=Mutex<(atKnot:Bool,count:Int)>((false,0))
    init(_ fault:Fault = .none) { self.fault=fault }
    func observedAtKnot() -> Bool { times.withLock { $0.atKnot } }
    func callCount() -> Int { times.withLock { $0.count } }
    private func finish(_ result:Double?,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        guard let result else { return nil }
        switch fault {
        case .none:return result
        case .wrongNil:return nil
        case .late:return result+0.01
        case .resetFailure:work=NumericalWork(budget:work.budget);throw .invalidInput
        case .cancel:throw .cancelled
        case .unknown:
            do throws(NumericalError) { try work.chargeOperations(7) } catch { throw .numerical(error) };throw .supplierWorkUnavailable
        }
    }
    func nextBoundary(_ program:PrescribedTrajectoryProgram,after time:Double,through limit:Double,policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        times.withLock { $0.atKnot = $0.atKnot || time.bitPattern == Double(1).bitPattern;$0.count+=1 }
        return try finish(PrescribedTrajectoryBoundaryQuery().nextBoundary(program,after:time,through:limit,policy:policy,work:&work),work:&work)
    }
    func nextBaseBoundary(_ program:PrescribedBaseTrajectoryProgram,after time:Double,through limit:Double,policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        times.withLock { $0.atKnot = $0.atKnot || time.bitPattern == Double(1).bitPattern;$0.count+=1 }
        return try finish(PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(program,after:time,through:limit,policy:policy,work:&work),work:&work)
    }
}
