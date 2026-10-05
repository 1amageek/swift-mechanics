public struct ControlClock: Equatable, Sendable {
    public let epochSeconds:Double,periodSeconds:Double,maximumTimeSeconds:Double
    public let maximumTicks:UInt64
    public init(epochSeconds:Double,periodSeconds:Double,maximumTimeSeconds:Double,maximumTicks:UInt64) throws(ControlFailure) {
        guard epochSeconds.isFinite,periodSeconds.isFinite,periodSeconds > 0,maximumTimeSeconds.isFinite,maximumTimeSeconds > epochSeconds,
              maximumTicks > 0 else { throw ControlFailure(.invalidInput,phase:"clock") }
        self.epochSeconds=epochSeconds;self.periodSeconds=periodSeconds;self.maximumTimeSeconds=maximumTimeSeconds;self.maximumTicks=maximumTicks
    }
    public func time(at tick:UInt64) throws(ControlFailure) -> Double {
        guard tick <= maximumTicks,tick <= 9_007_199_254_740_992 else { throw ControlFailure(.capacity,phase:"clock") }
        let time=epochSeconds+Double(tick)*periodSeconds
        guard time.isFinite,time <= maximumTimeSeconds else { throw ControlFailure(.capacity,phase:"clock") }
        return time
    }
    public func end(after tick:UInt64) throws(ControlFailure) -> Double {
        guard tick < maximumTicks else { throw ControlFailure(.capacity,phase:"clock") }
        let start=try time(at:tick),end=try time(at:tick+1),dt=end-start
        guard dt.isFinite,dt > 0,start+dt == end else { throw ControlFailure(.invalidInput,phase:"clock") }
        return end
    }
}
