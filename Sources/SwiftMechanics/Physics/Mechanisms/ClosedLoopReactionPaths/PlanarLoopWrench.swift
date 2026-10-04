/// Continuous physical force/couple on the modeled axes; no transverse bearing authority.
public struct PlanarLoopWrench: Equatable, Sendable {
    public let forceX: Double
    public let forceY: Double
    public let momentZ: Double
    internal init(forceX:Double,forceY:Double,momentZ:Double) {
        self.forceX=forceX;self.forceY=forceY;self.momentZ=momentZ
    }
}
