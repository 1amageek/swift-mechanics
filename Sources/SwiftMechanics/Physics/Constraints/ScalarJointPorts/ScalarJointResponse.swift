
public struct ScalarJointResponse: Sendable {
    public let smoothEffort: Double
    public let potentialEnergy: Double
    public let damperPower: Double
    public let friction: JointFrictionResponse
    public let coordinateDimension: PhysicalDimension
    public let effortDimension: PhysicalDimension
    public init(smoothEffort: Double, potentialEnergy: Double, damperPower: Double, friction: JointFrictionResponse,
                coordinateDimension: PhysicalDimension, effortDimension: PhysicalDimension) {
        self.smoothEffort=smoothEffort; self.potentialEnergy=potentialEnergy; self.damperPower=damperPower; self.friction=friction
        self.coordinateDimension=coordinateDimension; self.effortDimension=effortDimension
    }
}
