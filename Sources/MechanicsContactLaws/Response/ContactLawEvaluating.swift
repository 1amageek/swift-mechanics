public protocol ContactLawEvaluating: Sendable {
    func initialHistory(identity: ContactIdentity, pair: ContactLawPair, timeSeconds: Double,
                        work: inout ContactWork) throws(ContactLawError) -> ContactHistory
    func evaluate(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                  policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactLawError) -> ContactResponse
}
