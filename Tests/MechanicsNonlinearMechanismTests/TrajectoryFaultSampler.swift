import SwiftMechanics

internal struct TrajectoryFaultSampler: PrescribedTrajectorySampling {
    func sample(_ program:PrescribedTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        let result=try AnalyticPrescribedTrajectorySampler().sample(program,time:time,policy:policy,work:&work)
        if time > 0.051 { work=NumericalWork(budget:work.budget) }
        return result
    }
}
