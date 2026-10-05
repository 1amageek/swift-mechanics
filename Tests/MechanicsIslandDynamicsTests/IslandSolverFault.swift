import SwiftMechanics
internal struct IslandSolverFault: ConstrainedMechanismSolving {
    let index:Int
    let fail:Bool
    func acceleration(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,drive:[Double],policy:MechanismSolvePolicy,work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        let actual=try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:drive,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        switch index { case 0:work=NumericalWork(budget:work.budget);case 1:dynamicsWork=NumericalWork(budget:dynamicsWork.budget);case 2:rankWork=NumericalWork(budget:rankWork.budget);default:linearWork=NumericalWork(budget:linearWork.budget) }
        if fail { throw .cancelled };return actual
    }
    func reconcileVelocity(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
}
