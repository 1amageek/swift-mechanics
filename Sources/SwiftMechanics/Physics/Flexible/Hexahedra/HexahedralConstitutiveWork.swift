public struct HexahedralConstitutiveWork: Equatable, Sendable {
    public let maximumCalls: Int
    public private(set) var calls: Int = 0

    public init(maximumCalls: Int) throws(HexahedralError) {
        guard maximumCalls >= 0 else { throw .invalidParameter }
        self.maximumCalls = maximumCalls
    }

    internal mutating func charge() throws(HexahedralError) {
        guard calls < maximumCalls else { throw .constitutiveCallLimit(limit: maximumCalls) }
        calls += 1
    }
}
