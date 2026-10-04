import SwiftMechanics

struct ContactFaultSupplier: ContactLawEvaluating {
    enum Mode: Equatable, Sendable { case wrongSource, failedPrefix, resetSuccess, resetFailure, changedBudget, exhaust, cancelSuccess, cancelFailure }
    let mode: Mode
    func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                        work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        try CompliantContactEvaluator().initialHistory(identity:identity,pair:pair,timeSeconds:timeSeconds,work:&work)
    }
    func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                  policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        let actual: ContactInput
        if mode == .wrongSource {
            actual=try ContactInput(identity:input.identity,basis:input.basis,separation:input.separation-0.01,
                relativeVelocity:input.relativeVelocity,relativeAngularVelocity:input.relativeAngularVelocity,
                startTimeSeconds:input.startTimeSeconds,timeStepSeconds:input.timeStepSeconds)
        } else { actual=input }
        let result=try CompliantContactEvaluator().evaluate(input:actual,pair:pair,accepted:accepted,policy:policy,work:&work)
        switch mode {
        case .failedPrefix: try work.consume(operations:37,scalarStorage:256,records:1); throw .normalDomain
        case .resetSuccess: work=ContactWork(budget:work.budget)
        case .resetFailure: work=ContactWork(budget:work.budget); throw .normalDomain
        case .changedBudget: work=ContactWork(budget:try ContactBudget(operations:work.budget.operations+1,scalarStorage:work.budget.scalarStorage,records:work.budget.records))
        case .exhaust: try work.consume(operations:work.budget.operations-work.operations,scalarStorage:256,records:1)
        case .cancelSuccess: withUnsafeCurrentTask { $0?.cancel() }
        case .cancelFailure: withUnsafeCurrentTask { $0?.cancel() }; throw .normalDomain
        case .wrongSource: break
        }
        return result
    }
}
