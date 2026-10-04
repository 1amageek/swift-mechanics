import SwiftMechanics
import Synchronization

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
final class ToothLawFault: ContactLawEvaluating, Sendable {
    enum Mode: Sendable { case fail, reset, cancelSuccess, cancelThrow, taskCancel }
    private struct State: Sendable { var cancelled=false; var supplierPrefix=0; var calls=0 }
    let mode: Mode
    private let state=Mutex(State())
    init(_ mode: Mode) { self.mode=mode }
    var cancelled: Bool { state.withLock{$0.cancelled} }
    var prefix: Int { state.withLock{$0.supplierPrefix} }
    var calls: Int { state.withLock{$0.calls} }
    func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                        work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        try CompliantContactEvaluator().initialHistory(identity:identity,pair:pair,timeSeconds:timeSeconds,work:&work)
    }
    func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory, policy: ContactAcceptancePolicy,
                  work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        let response=try CompliantContactEvaluator().evaluate(input:input,pair:pair,accepted:accepted,policy:policy,work:&work)
        try work.consume(operations:73,scalarStorage:0,records:0)
        state.withLock{$0.supplierPrefix=work.operations; $0.calls += 1}
        switch mode {
        case .reset: work=ContactWork(budget:work.budget); throw .invalidInput
        case .fail: throw .invalidInput
        case .cancelSuccess: state.withLock{$0.cancelled=true}; return response
        case .cancelThrow: state.withLock{$0.cancelled=true}; throw .invalidInput
        case .taskCancel: withUnsafeCurrentTask{$0?.cancel()}; return response
        }
    }
}
