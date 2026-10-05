public struct AerodynamicPolarResponse: Sendable, Equatable {
    public let load: FramedPointLoad
    public let angle: Double
    public let liftCoefficient: Double
    public let dragCoefficient: Double
    public let dynamicPressure: Double
    public let relativeDissipatedPower: Double
    public let prescribedMediumPower: Double
    internal init(load: FramedPointLoad, angle: Double, liftCoefficient: Double, dragCoefficient: Double,
                  dynamicPressure: Double, relativeDissipatedPower: Double, prescribedMediumPower: Double) {
        self.load = load; self.angle = angle; self.liftCoefficient = liftCoefficient
        self.dragCoefficient = dragCoefficient; self.dynamicPressure = dynamicPressure
        self.relativeDissipatedPower = relativeDissipatedPower; self.prescribedMediumPower = prescribedMediumPower
    }
}
