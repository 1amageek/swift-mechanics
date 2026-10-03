import MechanicsContactLaws
struct ResettingGranularLaw: ContactLawEvaluating, Sendable {
    func initialHistory(identity: ContactIdentity,pair: ContactLawPair,timeSeconds: Double,work: inout ContactWork) throws(ContactLawError) -> ContactHistory {
        try CompliantContactEvaluator().initialHistory(identity:identity,pair:pair,timeSeconds:timeSeconds,work:&work)
    }
    func evaluate(input: ContactInput,pair: ContactLawPair,accepted: ContactHistory,policy: ContactAcceptancePolicy,work: inout ContactWork) throws(ContactLawError) -> ContactResponse {
        let result=try CompliantContactEvaluator().evaluate(input:input,pair:pair,accepted:accepted,policy:policy,work:&work)
        work=ContactWork(budget:work.budget)
        return result
    }
}
