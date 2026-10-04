import SwiftMechanics

struct CancellingHistoryLaw: ContactLawEvaluating {
    let afterHistory: @Sendable () -> Void
    private let base=CompliantContactEvaluator()
    func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                        work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        let result=try base.initialHistory(identity:identity,pair:pair,timeSeconds:timeSeconds,work:&work)
        afterHistory()
        return result
    }
    func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                  policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        try base.evaluate(input:input,pair:pair,accepted:accepted,policy:policy,work:&work)
    }
}
