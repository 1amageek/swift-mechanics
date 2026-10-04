public struct FluidLoadResponse: Equatable, Sendable {
    public let load: FramedPointLoad
    public let forceVelocityDerivative: Matrix3
    public let relativeDissipatedPower: Double
    public let prescribedMediumPower: Double
    internal init(load: FramedPointLoad, forceVelocityDerivative: Matrix3, relativeDissipatedPower: Double,
                  prescribedMediumPower: Double) {
        self.load = load; self.forceVelocityDerivative = forceVelocityDerivative
        self.relativeDissipatedPower = relativeDissipatedPower; self.prescribedMediumPower = prescribedMediumPower
    }
}
