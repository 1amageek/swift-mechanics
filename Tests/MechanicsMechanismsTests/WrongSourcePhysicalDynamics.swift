import SwiftMechanics

/// Return a valid actual producer result from a different admitted physical source.
internal struct WrongSourcePhysicalDynamics: PhysicalRigidDynamicsSolving {
    let other:PhysicalRigidDynamicsSystem
    private var producer:DenseRigidDynamics { DenseRigidDynamics(physicalEquations:RigidEquationKernel()) }
    func forward(_ system:PhysicalRigidDynamicsSystem,driveForce:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try producer.forward(other,driveForce:driveForce,policy:policy,work:&work)
    }
    func inverse(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try producer.inverse(other,acceleration:acceleration,policy:policy,work:&work)
    }
    func inverseMassProduct(_ system:PhysicalRigidDynamicsSystem,rightHandSide:[Double],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try producer.inverseMassProduct(other,rightHandSide:rightHandSide,policy:policy,work:&work)
    }
    func mixed(_ system:PhysicalRigidDynamicsSystem,partition:[MixedCoordinate],policy:DynamicsSolvePolicy,work:inout NumericalWork) throws(DynamicsError) -> PhysicalDynamicsSolution {
        try producer.mixed(other,partition:partition,policy:policy,work:&work)
    }
}
