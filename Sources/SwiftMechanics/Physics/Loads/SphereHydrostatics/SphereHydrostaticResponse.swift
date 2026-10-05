public struct SphereHydrostaticResponse: Sendable, Equatable {
    public let load: FramedPointLoad
    public let displacedVolume: Double
    public let centerOfBuoyancy: Vector3?
    public let waterplaneArea: Double
    public let forcePositionDerivative: Matrix3
    internal init(load: FramedPointLoad, displacedVolume: Double, centerOfBuoyancy: Vector3?,
                  waterplaneArea: Double, forcePositionDerivative: Matrix3) {
        self.load = load; self.displacedVolume = displacedVolume; self.centerOfBuoyancy = centerOfBuoyancy
        self.waterplaneArea = waterplaneArea; self.forcePositionDerivative = forcePositionDerivative
    }
}
