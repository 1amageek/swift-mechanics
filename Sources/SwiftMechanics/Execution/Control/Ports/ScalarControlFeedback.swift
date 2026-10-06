public struct ScalarControlFeedback: Sendable {
    public let sourceTime: Double
    public let position: Double
    public let rate: Double
    public let port: ScalarControlPort
    internal init(sourceTime:Double,position:Double,rate:Double,port:ScalarControlPort) {
        self.sourceTime=sourceTime;self.position=position;self.rate=rate;self.port=port
    }
}
