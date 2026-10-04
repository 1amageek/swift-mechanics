import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class PhysicalEquationFault: PhysicalRigidEquationComputing, Sendable {
    enum Mode: Equatable, Sendable { case observe, resetReturn, resetThrow, failAfterPrefix }
    private let mode:Mode
    private let calls=Mutex(0)
    init(_ mode:Mode) { self.mode=mode }
    func count() -> Int { calls.withLock { $0 } }
    func assemble(_ input:PhysicalRigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        calls.withLock { $0+=1 }
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
        switch mode {
        case .observe: return
        case .resetReturn: work=NumericalWork(budget:work.budget)
        case .resetThrow: work=NumericalWork(budget:work.budget);throw .cancelled
        case .failAfterPrefix: throw .cancelled
        }
    }
    func inertialWrench(_ system:PhysicalRigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}
