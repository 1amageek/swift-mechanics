public struct DerivativeSupplierWork: Equatable, Sendable {
    public let maximumCalls: Int
    public private(set) var calls: Int = 0
    public init(maximumCalls: Int) throws(DerivativeError) {
        guard maximumCalls >= 0 else { throw .invalidInput }; self.maximumCalls=maximumCalls
    }
    public mutating func chargeCall() throws(DerivativeError) {
        guard calls < maximumCalls else { throw .capacityExceeded }; calls += 1
    }
}
