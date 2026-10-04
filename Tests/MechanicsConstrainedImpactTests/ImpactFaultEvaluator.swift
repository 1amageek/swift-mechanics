import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ImpactFaultEvaluator: ConstraintEvaluating, Sendable {
    private let calls = Mutex(0)
    private let fault: ConstrainedImpactFault
    init(_ fault: ConstrainedImpactFault) { self.fault = fault }
    var callCount: Int { calls.withLock { $0 } }
    func evaluate(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                  policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintEvaluation {
        calls.withLock { $0 += 1 }
        if fault == .failure { throw .invalidInput }
        let value = try QuadraticConstraintEvaluator().evaluate(system,position:position,velocity:velocity,time:time,policy:policy,work:&work)
        if fault == .falseResult {
            var jacobian = value.jacobian; jacobian[0] += 1
            return ConstraintEvaluation(normalizedPosition:value.normalizedPosition,normalizedVelocity:value.normalizedVelocity,
                values:value.values,jacobian:jacobian,timeDerivative:value.timeDerivative,accelerationBias:value.accelerationBias,
                rowIDs:value.rowIDs,layoutRevision:value.layoutRevision)
        }
        work = NumericalWork(budget:work.budget)
        if fault == .resetFailure { throw .invalidInput }
        if fault == .cancelled { throw .cancelled }
        return value
    }
}
