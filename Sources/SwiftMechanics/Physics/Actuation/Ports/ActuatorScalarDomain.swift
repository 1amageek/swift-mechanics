public struct ActuatorScalarDomain: Equatable, Sendable {
    public let primaryLower:Double,primaryUpper:Double,secondaryLower:Double,secondaryUpper:Double
    public init(primaryLower:Double,primaryUpper:Double,secondaryLower:Double,secondaryUpper:Double) throws(ActuationError) {
        guard primaryLower.isFinite,primaryUpper.isFinite,secondaryLower.isFinite,secondaryUpper.isFinite,
              primaryLower <= primaryUpper,secondaryLower <= secondaryUpper else { throw .invalidInput }
        self.primaryLower=primaryLower;self.primaryUpper=primaryUpper;self.secondaryLower=secondaryLower;self.secondaryUpper=secondaryUpper
    }
    public func contains(primary:Double,secondary:Double) -> Bool {
        primary.isFinite && secondary.isFinite && primary >= primaryLower && primary <= primaryUpper && secondary >= secondaryLower && secondary <= secondaryUpper
    }
}
