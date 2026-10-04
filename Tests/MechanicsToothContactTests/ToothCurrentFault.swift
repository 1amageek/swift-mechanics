import SwiftMechanics
import Synchronization

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
final class ToothCurrentFault: ContactCurrentEvaluating, Sendable {
    enum Mode: Sendable { case wrongForce, wrongCouple, reset, fail, cancelSuccess, cancelThrow, taskCancel }
    private struct State: Sendable { var cancelled=false; var prefix=0; var calls=0 }
    private let state=Mutex(State())
    let mode: Mode
    init(_ mode: Mode) { self.mode=mode }
    var cancelled: Bool { state.withLock{$0.cancelled} }
    var prefix: Int { state.withLock{$0.prefix} }
    var calls: Int { state.withLock{$0.calls} }
    func sample(input: ContactCurrentInput, pair: ContactLawPair, accepted: ContactHistory, policy: ContactAcceptancePolicy,
                work: inout ContactWork) throws(ContactCurrentError) -> ContactCurrentResponse {
        let supplied: ContactCurrentInput
        do {
            switch mode {
            case .wrongForce: supplied=try ContactCurrentInput(identity:input.identity,basis:input.basis,separation:input.separation-0.01,
                relativeVelocity:input.relativeVelocity,relativeAngularVelocity:input.relativeAngularVelocity,timeSeconds:input.timeSeconds)
            case .wrongCouple: supplied=try ContactCurrentInput(identity:input.identity,basis:input.basis,separation:input.separation,
                relativeVelocity:input.relativeVelocity,relativeAngularVelocity:input.relativeAngularVelocity.adding(.unitX),timeSeconds:input.timeSeconds)
            default: supplied=input
            }
        } catch let error as ContactCurrentError { throw error }
        catch { throw .law(.invalidInput) }
        let response=try CompliantContactCurrentEvaluator().sample(input:supplied,pair:pair,accepted:accepted,policy:policy,work:&work)
        do { try work.consume(operations:73,scalarStorage:0,records:0) } catch { throw .law(error) }
        state.withLock{$0.prefix=work.operations; $0.calls += 1}
        switch mode {
        case .wrongForce,.wrongCouple: return response
        case .reset: work=ContactWork(budget:work.budget); throw .law(.invalidInput)
        case .fail: throw .law(.invalidInput)
        case .cancelSuccess: state.withLock{$0.cancelled=true}; return response
        case .cancelThrow: state.withLock{$0.cancelled=true}; throw .law(.invalidInput)
        case .taskCancel: withUnsafeCurrentTask{$0?.cancel()}; return response
        }
    }
}
