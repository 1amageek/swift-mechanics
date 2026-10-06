public protocol ContactCurrentEvaluating: Sendable {
    func sample(input: ContactCurrentInput, pair: ContactLawPair, accepted: ContactHistory,
                policy: ContactAcceptancePolicy, work: inout ContactWork) throws(ContactCurrentError) -> ContactCurrentResponse
}
