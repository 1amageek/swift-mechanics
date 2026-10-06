import SwiftMechanics

internal struct TrajectoryFaultBaseSampler: PrescribedBaseTrajectorySampling {
    enum Fault:Sendable { case wrongTime,resetSuccess,resetFailure,cancel,unknown }
    let fault:Fault
    func sampleBase(_ program:PrescribedBaseTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        if time > 0.051 {
            switch fault {
            case .wrongTime:return try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:time+0.001,policy:policy,work:&work)
            case .resetSuccess:
                let result=try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:time,policy:policy,work:&work)
                work=NumericalWork(budget:work.budget);return result
            case .resetFailure:work=NumericalWork(budget:work.budget);throw .invalidInput
            case .cancel:throw .cancelled
            case .unknown:
                do throws(NumericalError) { try work.chargeOperations(7) } catch { throw .numerical(error) };throw .supplierWorkUnavailable
            }
        }
        return try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:time,policy:policy,work:&work)
    }
}
