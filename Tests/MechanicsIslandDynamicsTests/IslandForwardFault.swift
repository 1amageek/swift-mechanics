import SwiftMechanics

internal struct IslandForwardFault: RigidDynamicsSolving {
    let fail:Bool
    let nested:Int
    init(fail:Bool,nested:Int = 0) { self.fail=fail;self.nested=nested }
    func forward(_ system:RigidDynamicsSystem,driveForce:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        let actual=try DenseRigidDynamics().forward(system,driveForce:driveForce,policy:policy,work:&work)
        work=NumericalWork(budget:work.budget)
        if fail {
            if nested == 1 { throw .loads(.cancelled) }
            if nested == 2 { throw .numerical(.cancelled,failedSupplierWorkUnavailable:true) }
            throw .cancelled
        };return actual
    }
    func inverse(_ system:RigidDynamicsSystem,acceleration:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().inverse(system,acceleration:acceleration,policy:policy,work:&work)
    }
    func inverseMassProduct(_ system:RigidDynamicsSystem,rightHandSide:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().inverseMassProduct(system,rightHandSide:rightHandSide,policy:policy,work:&work)
    }
    func mixed(_ system:RigidDynamicsSystem,partition:[MixedCoordinate],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try DenseRigidDynamics().mixed(system,partition:partition,policy:policy,work:&work)
    }
}
