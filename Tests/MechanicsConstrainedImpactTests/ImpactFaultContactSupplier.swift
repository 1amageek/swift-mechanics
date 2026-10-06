import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ImpactFaultContactSupplier: ContactImpactPredicting, Sendable {
    private let calls = Mutex(0)
    private let fault: ConstrainedImpactFault
    private let substitute: ContactLawPair?
    init(_ fault: ConstrainedImpactFault, substitute: ContactLawPair? = nil) { self.fault = fault; self.substitute = substitute }
    var callCount: Int { calls.withLock { $0 } }
    func predict(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                 work: inout ContactWork) throws(ContactLawError) -> ContactImpactPrediction {
        calls.withLock { $0 += 1 }
        if fault == .failure { throw .invalidInput }
        let value = try ThresholdRestitutionPredictor().predict(pair:substitute ?? pair,approachSpeed:approachSpeed,incomingNormalEnergy:incomingNormalEnergy,work:&work)
        if fault == .falseResult { return value }
        work = ContactWork(budget:work.budget)
        if fault == .resetFailure { throw .invalidInput }
        if fault == .cancelled { throw .cancelled }
        return value
    }
}
