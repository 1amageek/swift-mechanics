import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ImpactFaultEquationSupplier: RigidEquationComputing, Sendable {
    private let calls = Mutex(0)
    private let loadReset: Bool
    private let fault: ConstrainedImpactFault
    private let substitute: RigidDynamicsInput?
    init(_ fault: ConstrainedImpactFault, loadReset: Bool = false, substitute: RigidDynamicsInput? = nil) {
        self.fault = fault; self.loadReset = loadReset; self.substitute = substitute
    }
    var callCount: Int { calls.withLock { $0 } }
    func assemble(_ input: RigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork,
                  work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        calls.withLock { $0 += 1 }
        if fault == .failure { throw .invalidInput }
        if let substitute { return try RigidEquationKernel().assemble(substitute,admission:admission,loadWork:&loadWork,work:&work) }
        let value = try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
        if loadReset { loadWork = LoadWork(budget:loadWork.budget) }
        else { work = NumericalWork(budget:work.budget) }
        if fault == .resetFailure { throw .invalidInput }
        if fault == .cancelled { throw .cancelled }
        return value
    }
    func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                               into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
        if fault == .falseResult {
            try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
            if !output.isEmpty { output[0] += 1 }
            return
        }
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system: RigidDynamicsSystem, body: EntityID, acceleration: [Double], referencePointWorld: Vector3,
                        work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3, requireComplete: Bool,
                work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}
