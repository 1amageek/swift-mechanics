public struct InertialApproximation: Equatable, Sendable {
    public let maximumMassErrorKilograms: Double
    public let maximumCenterErrorMeters: Double
    public let maximumInertiaElementErrorKilogramMetersSquared: Double

    public init(maximumMassErrorKilograms: Double, maximumCenterErrorMeters: Double,
                maximumInertiaElementErrorKilogramMetersSquared: Double) throws(ModelError) {
        guard maximumMassErrorKilograms.isFinite, maximumMassErrorKilograms >= 0,
              maximumCenterErrorMeters.isFinite, maximumCenterErrorMeters >= 0,
              maximumInertiaElementErrorKilogramMetersSquared.isFinite,
              maximumInertiaElementErrorKilogramMetersSquared >= 0 else { throw .invalidMetadata }
        self.maximumMassErrorKilograms = maximumMassErrorKilograms
        self.maximumCenterErrorMeters = maximumCenterErrorMeters
        self.maximumInertiaElementErrorKilogramMetersSquared = maximumInertiaElementErrorKilogramMetersSquared
    }
}
