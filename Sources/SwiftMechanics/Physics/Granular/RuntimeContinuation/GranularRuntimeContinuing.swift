public protocol GranularRuntimeContinuing: Sendable {
    var source: GranularRuntimeSource { get }
    var schema: RuntimeContributorSchema { get }
    func initial(work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> GranularRuntimeContinuation
    func encode(_ continuation: GranularRuntimeContinuation, work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> RuntimeContributorState
    func decode(_ record: RuntimeContributorState, work: inout GranularRuntimeWork) throws(GranularRuntimeError) -> GranularRuntimeContinuation
}
