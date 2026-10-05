/// Native displacement q=qpos-ref, in SI/radians; finite bounds are caller authority.
public struct MJCFCoordinateDomain: Sendable {
    public let jointName: String
    public let coordinateID: UInt64
    public let minimum: Double
    public let maximum: Double
    public let scale: Double
    public init(jointName: String, coordinateID: UInt64, minimum: Double, maximum: Double, scale: Double) throws(MJCFError) {
        guard !jointName.isEmpty, minimum.isFinite, maximum.isFinite, minimum <= 0, maximum >= 0,
              minimum <= maximum, scale.isFinite, scale > 0 else { throw .invalidInput(node: -1, field: "coordinateDomain") }
        self.jointName = jointName; self.coordinateID = coordinateID; self.minimum = minimum; self.maximum = maximum; self.scale = scale
    }
}
