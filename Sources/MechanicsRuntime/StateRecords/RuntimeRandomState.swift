public struct RuntimeRandomState: Equatable, Sendable {
    public let seed: UInt64
    public private(set) var state: UInt64
    public private(set) var draws: UInt64
    public init(seed: UInt64) { self.seed = seed; self.state = seed; self.draws = 0 }
    internal init(seed: UInt64, state: UInt64, draws: UInt64) throws(RuntimeFailure) {
        guard state == seed &+ (draws &* 0x9e3779b97f4a7c15) else { throw RuntimeFailure(.corruptCheckpoint, message: "Random state is inconsistent with seed/draw continuation.") }
        self.seed = seed; self.state = state; self.draws = draws
    }
    public mutating func next() throws(RuntimeFailure) -> UInt64 {
        guard draws < UInt64.max else { throw RuntimeFailure(.capacityExceeded, message: "Random draw counter overflow.") }
        // SplitMix64 intentionally wraps its state and mixing products modulo 2^64.
        state &+= 0x9e3779b97f4a7c15; draws += 1
        return Self.mix(state)
    }
    public static func worldSeed(rootSeed: UInt64, index: UInt64) -> UInt64 {
        mix(rootSeed &+ 0x9e3779b97f4a7c15 &* (index &+ 1))
    }
    private static func mix(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed = (mixed ^ (mixed >> 30)) &* 0xbf58476d1ce4e5b9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94d049bb133111eb
        return mixed ^ (mixed >> 31)
    }
}
