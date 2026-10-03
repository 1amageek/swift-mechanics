import MechanicsCore
import MechanicsJoints
import MechanicsNumerics
import MechanicsDerivatives
struct SpringForceProvider: DifferentiatedForceProviding {
    enum Behavior: Equatable, Sendable { case valid, unavailable, partial, resized, failed, resetLedger }
    let behavior: Behavior
    var metadata: ForceDerivativeMetadata { ForceDerivativeMetadata(revision:7,coordinateCount:1,parameterIDs:[101],parameterDimensions:[PhysicalDimension(length:2,mass:1,angle:-2)],
        availability:behavior == .unavailable ? .unavailable : .analytic) }
    func value(_ snapshot: KinematicSnapshot, state: KinematicState, parameters: [Double], into output: inout [Double],
               work: inout NumericalWork) throws(DerivativeError) {
        do { try work.chargeOperations(2) } catch { throw .numerical(error) }
        if behavior == .resetLedger { work = NumericalWork(budget: work.budget) }
        if behavior == .failed { throw .callbackFailure }
        if behavior == .partial { return }
        if behavior == .resized { output.append(0); return }
        guard parameters[0] > 0 else { throw .invalidInput }
        output[0] = -parameters[0]*state.q[0]
    }
    func direction(_ tangent: TreeTangent, state: KinematicState, treeDirection: TreeDirection, parameters: [Double], parameterDirection: [Double],
                   into output: inout [Double], work: inout NumericalWork) throws(DerivativeError) {
        if behavior == .resetLedger { throw .callbackFailure }
        do { try work.chargeOperations(4) } catch { throw .numerical(error) }
        output[0] = -parameterDirection[0]*state.q[0]-parameters[0]*treeDirection.configuration[0]
    }
}
