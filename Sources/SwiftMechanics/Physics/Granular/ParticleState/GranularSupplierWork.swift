public struct GranularSupplierWork: Sendable {
    public let maximumCalls: Int
    public private(set) var calls: Int = 0
    public init(maximumCalls: Int) throws(GranularError) { guard maximumCalls >= 0 else { throw .invalidInput }; self.maximumCalls=maximumCalls }
    internal mutating func begin() throws(GranularError) {
        guard calls < maximumCalls else { throw .capacity(resource:"supplierCalls",limit:maximumCalls) }; calls += 1
    }
}
