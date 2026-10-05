public struct TireSlip: Equatable, Sendable {
    public let longitudinalRatio: Double
    public let lateralAngle: Double
    public let lateralTangent: Double
    public let longitudinalSurfaceSpeed: Double
    public let lateralSurfaceSpeed: Double

    internal init(longitudinalRatio: Double, lateralAngle: Double, lateralTangent: Double,
                  longitudinalSurfaceSpeed: Double, lateralSurfaceSpeed: Double) {
        self.longitudinalRatio = longitudinalRatio; self.lateralAngle = lateralAngle
        self.lateralTangent = lateralTangent; self.longitudinalSurfaceSpeed = longitudinalSurfaceSpeed
        self.lateralSurfaceSpeed = lateralSurfaceSpeed
    }
}
