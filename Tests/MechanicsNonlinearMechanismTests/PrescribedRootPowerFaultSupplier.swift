import SwiftMechanics

internal struct PrescribedRootPowerFaultSupplier: PhysicalPowerPartitioning {
    enum Fault:Sendable { case acceleration,resetSuccess,resetFailure,cancel }
    let fault:Fault
    func partitionedPower(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],knownCoordinates:[Int],drive:[Double],geometricReaction:[Double],
                          policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> PartitionedMechanicalPower {
        if system.input.snapshot.time > 0.051 {
            switch fault {
            case .acceleration:
                var changed=acceleration;changed[0]+=0.1
                return try RigidEquationKernel().partitionedPower(system,acceleration:changed,knownCoordinates:knownCoordinates,drive:drive,geometricReaction:geometricReaction,policy:policy,work:&work)
            case .resetFailure:work=NumericalWork(budget:work.budget);throw .invalidInput
            case .cancel:throw .cancelled
            case .resetSuccess:
                let result=try RigidEquationKernel().partitionedPower(system,acceleration:acceleration,knownCoordinates:knownCoordinates,drive:drive,geometricReaction:geometricReaction,policy:policy,work:&work)
                work=NumericalWork(budget:work.budget);return result
            }
        }
        return try RigidEquationKernel().partitionedPower(system,acceleration:acceleration,knownCoordinates:knownCoordinates,drive:drive,geometricReaction:geometricReaction,policy:policy,work:&work)
    }
}
