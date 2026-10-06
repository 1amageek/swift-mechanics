public struct FieldConstitutiveWork: Equatable, Sendable {
    public let maximumCalls: Int
    public private(set) var calls: Int = 0
    public init(maximumCalls: Int) throws(FieldOutputError) {
        guard maximumCalls >= 0 else { throw .invalidInput }; self.maximumCalls = maximumCalls
    }
    internal mutating func charge() throws(FieldOutputError) {
        guard calls < maximumCalls else { throw .constitutiveCallLimit }; calls += 1
    }
}
