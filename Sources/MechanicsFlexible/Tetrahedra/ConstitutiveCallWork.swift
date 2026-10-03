public struct ConstitutiveCallWork: Equatable, Sendable {
    public let maximumCalls: Int
    public private(set) var calls: Int = 0
    public init(maximumCalls: Int) throws(FlexibleError) { guard maximumCalls >= 0 else { throw .invalidParameter }; self.maximumCalls = maximumCalls }
    internal mutating func charge() throws(FlexibleError) {
        guard calls < maximumCalls else { throw .constitutiveCallLimit(limit:maximumCalls) }; calls += 1
    }
}
