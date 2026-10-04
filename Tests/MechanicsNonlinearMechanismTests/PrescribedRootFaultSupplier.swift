import SwiftMechanics

internal struct PrescribedRootFaultSupplier: PrescribedBaseMotionSampling {
    enum Fault:Sendable { case wrongTime,resetSuccess,resetFailure,cancel,unknown }
    let fault:Fault
    func sampleBase(_ program:PrescribedBaseMotionProgram,time:Double,policy:PrescribedMotionPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        if time > 0.051 {
            switch fault {
            case .wrongTime: return try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:time+0.001,policy:policy,work:&work)
            case .resetSuccess:
                let result=try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:time,policy:policy,work:&work)
                work=NumericalWork(budget:work.budget);return result
            case .resetFailure:work=NumericalWork(budget:work.budget);throw .invalidInput
            case .cancel:throw .cancelled
            case .unknown:
                do throws(NumericalError) { try work.chargeOperations(7) } catch { throw .numerical(error) }
                throw .supplierWorkUnavailable
            }
        }
        return try AnalyticPrescribedBaseMotionSampler().sampleBase(program,time:time,policy:policy,work:&work)
    }
}
