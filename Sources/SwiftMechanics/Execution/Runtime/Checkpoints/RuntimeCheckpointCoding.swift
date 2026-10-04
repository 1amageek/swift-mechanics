public protocol RuntimeCheckpointCoding: Sendable {
    func encode(_ checkpoint: RuntimeCheckpoint, capacity: RuntimeCapacity) throws(RuntimeFailure) -> [UInt8]
    func decode(_ bytes: [UInt8], capacity: RuntimeCapacity) throws(RuntimeFailure) -> RuntimeCheckpoint
}
