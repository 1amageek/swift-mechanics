import SwiftMechanics

internal struct ResettingDynamicsProvider: RigidDynamicsSolving {
    func forward(_ system:RigidDynamicsSystem,driveForce:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        let result=try DenseRigidDynamics().forward(system,driveForce:driveForce,policy:policy,work:&work)
        work=NumericalWork(budget:work.budget);return result
    }
    func inverseMassProduct(_ system:RigidDynamicsSystem,rightHandSide:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().inverseMassProduct(system,rightHandSide:rightHandSide,policy:policy,work:&work)
    }
    func inverse(_ system:RigidDynamicsSystem,acceleration:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().inverse(system,acceleration:acceleration,policy:policy,work:&work)
    }
    func mixed(_ system:RigidDynamicsSystem,partition:[MixedCoordinate],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().mixed(system,partition:partition,policy:policy,work:&work)
    }
}
