public protocol FluidContinuationCoding: Sendable {
    var channel: FluidChannel { get }
    var schema: RuntimeContributorSchema { get }
    var encodedSize: Int { get }
    func encode(_ state: FluidState, work: inout FluidByteWork) throws(FluidError) -> RuntimeContributorState
    func decode(_ record: RuntimeContributorState, work: inout FluidByteWork) throws(FluidError) -> FluidState
}
