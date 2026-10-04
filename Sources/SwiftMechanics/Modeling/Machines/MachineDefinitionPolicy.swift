public struct MachineDefinitionPolicy: Equatable, Sendable {
    public let maximumNodes: Int
    public let maximumRecords: Int
    public let maximumIdentifierBytes: Int
    public let maximumDepth: Int
    public let maximumIterations: Int

    public init(maximumNodes: Int, maximumRecords: Int, maximumIdentifierBytes: Int,
                maximumDepth: Int, maximumIterations: Int) throws(MachineDefinitionFailure) {
        guard maximumNodes >= 0, maximumRecords >= 0, maximumIdentifierBytes >= 0,
              maximumDepth > 0, maximumIterations >= 0 else { throw .invalidPolicy }
        self.maximumNodes = maximumNodes; self.maximumRecords = maximumRecords
        self.maximumIdentifierBytes = maximumIdentifierBytes; self.maximumDepth = maximumDepth
        self.maximumIterations = maximumIterations
    }
}
