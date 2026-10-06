import SwiftMechanics

struct FaultCurrentSampler:ContactCurrentEvaluating {
    enum Mode:Sendable { case foreignSeparation,resetSuccess,resetFailure }
    let mode:Mode
    func sample(input:ContactCurrentInput,pair:ContactLawPair,accepted:ContactHistory,policy:ContactAcceptancePolicy,work:inout ContactWork) throws(ContactCurrentError)->ContactCurrentResponse {
        let queried:ContactCurrentInput
        if mode == .foreignSeparation {
            queried=try ContactCurrentInput(identity:input.identity,basis:input.basis,separation:2*input.separation,
                relativeVelocity:input.relativeVelocity,relativeAngularVelocity:input.relativeAngularVelocity,timeSeconds:input.timeSeconds)
        } else { queried=input }
        let result=try CompliantContactCurrentEvaluator().sample(input:queried,pair:pair,accepted:accepted,policy:policy,work:&work)
        switch mode {
        case .resetSuccess: work=ContactWork(budget:work.budget)
        case .resetFailure: work=ContactWork(budget:work.budget);throw .law(.staleHistory)
        case .foreignSeparation: break
        }
        return result
    }
}
