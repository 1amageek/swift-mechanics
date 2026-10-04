public struct ValueGranularCheckpoints: GranularCheckpointing, Sendable {
    public init() {}
    public func capture(_ state: GranularState, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) -> GranularCheckpoint {
        try validate(state,policy:policy,work:&work)
        return GranularCheckpoint(state:state)
    }
    public func restore(_ checkpoint: GranularCheckpoint, model: GranularModel, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) -> GranularState {
        try GranularArithmetic.check(policy)
        guard checkpoint.state.model === model else { throw .staleCheckpoint }
        try validate(checkpoint.state,policy:policy,work:&work)
        return checkpoint.state
    }
    private func validate(_ state: GranularState,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.check(policy)
        let n=state.motions.count, c=state.contacts.count
        try GranularAdmission.capacity(n,state.model.boundaries.count,policy:policy)
        guard c <= policy.maximumContacts else { throw .capacity(resource:"contacts",limit:policy.maximumContacts) }
        try GranularArithmetic.storage(GranularArithmetic.addCount(GranularArithmetic.product(n,9),GranularArithmetic.addCount(GranularArithmetic.product(c,100),8)),work:&work)
        // No data copy or traversal is needed: only producer-created immutable state can inhabit this checkpoint.
        try GranularArithmetic.charge(32,policy:policy,work:&work)
        try GranularArithmetic.check(policy)
    }
}
