
public protocol PlanarContinuationCoding: Sendable {
    var grid: PlanarGrid { get }
    var model: ModelStamp { get }
    var schema: RuntimeContributorSchema { get }
    var encodedSize: Int { get }
    var requiredScratchBytes: Int { get }
    func encode(_ state: PlanarState, work: inout PlanarContinuationWork) throws(PlanarContinuationError) -> RuntimeContributorState
    func decode(_ record: RuntimeContributorState, work: inout PlanarContinuationWork) throws(PlanarContinuationError) -> PlanarState
}
