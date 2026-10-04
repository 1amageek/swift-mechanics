public struct StationaryLoadSelection: Equatable, Sendable {
    public let programID:UInt64
    public let revision:UInt64
    public let generation:UInt64
    public init(programID:UInt64,revision:UInt64,generation:UInt64) { self.programID=programID;self.revision=revision;self.generation=generation }
}
