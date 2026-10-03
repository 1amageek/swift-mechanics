public struct DriveCommand: Equatable, Sendable {
    public let mode:DriveMode,value:Double
    public init(mode:DriveMode,value:Double) throws(ActuationError) { guard value.isFinite else { throw .invalidInput };self.mode=mode;self.value=value }
}
