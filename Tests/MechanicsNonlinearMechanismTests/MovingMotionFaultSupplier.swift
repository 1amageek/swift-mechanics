import SwiftMechanics

internal struct MovingMotionFaultSupplier: PrescribedMotionSampling {
    enum Fault:Sendable { case resetSuccess,resetFailure,cancel,wrongTime,unknown }
    let fault:Fault
    func sample(_ program:PrescribedMotionProgram,time:Double,policy:PrescribedMotionPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        if time > 0.051 {
            switch fault {
            case .resetSuccess:
                let result=try AnalyticPrescribedMotionSampler().sample(program,time:time,policy:policy,work:&work)
                work=NumericalWork(budget:work.budget);return result
            case .resetFailure: work=NumericalWork(budget:work.budget);throw .invalidInput
            case .cancel: throw .cancelled
            case .unknown: throw .supplierWorkUnavailable
            case .wrongTime: return try AnalyticPrescribedMotionSampler().sample(program,time:time+0.01,policy:policy,work:&work)
            }
        }
        return try AnalyticPrescribedMotionSampler().sample(program,time:time,policy:policy,work:&work)
    }
}
