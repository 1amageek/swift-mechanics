public struct EquilibriumLoadCase: Sendable {
    public let identity: String
    public let parameter: Double
    public let time: Double
    public init(identity:String,parameter:Double,time:Double) { self.identity=identity;self.parameter=parameter;self.time=time }
}
