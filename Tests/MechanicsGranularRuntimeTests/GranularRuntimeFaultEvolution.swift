import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct GranularRuntimeFaultEvolution: GranularEvolving, Sendable {
    typealias Fault=GranularRuntimeSupplierFault
    let fault: Fault
    let failsAfterReset: Bool
    let flag: GranularRuntimeCancellationFlag?
    init(_ fault: Fault,fails: Bool = false,flag: GranularRuntimeCancellationFlag? = nil) { self.fault=fault;failsAfterReset=fails;self.flag=flag }
    func step(accepted: GranularState,timeStepSeconds: Double,gravity: Vector3,policy: GranularPolicy,
              workspace: inout GranularWorkspace,numericalWork: inout NumericalWork,collisionWork: inout CollisionWork,
              contactWork: inout ContactWork,supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularStepResult {
        let result=try ReferenceGranularEvolution().step(accepted:accepted,timeStepSeconds:timeStepSeconds,
            gravity:fault == .wrongGravity ? .zero : gravity,policy:policy,workspace:&workspace,numericalWork:&numericalWork,
            collisionWork:&collisionWork,contactWork:&contactWork,supplierWork:&supplierWork)
        switch fault {
        case .numericalReset: numericalWork=NumericalWork(budget:numericalWork.budget)
        case .collisionReset: collisionWork=CollisionWork(budget:collisionWork.budget)
        case .contactReset: contactWork=ContactWork(budget:contactWork.budget)
        case .supplierReset: supplierWork=try GranularSupplierWork(maximumCalls:supplierWork.maximumCalls)
        case .cancellation: flag?.set()
        case .failure: throw .residual(value:26,threshold:0)
        case .wrongGravity: break
        }
        if failsAfterReset { throw .invalidSupplierOutput }
        return result
    }
}
