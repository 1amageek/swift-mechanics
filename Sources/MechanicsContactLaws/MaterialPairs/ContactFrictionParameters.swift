public struct ContactFrictionParameters: Equatable, Sendable {
    public let staticFirst: Double, staticSecond: Double
    public let dynamicFirst: Double, dynamicSecond: Double
    public let tangentialStiffness: Double
    public let transitionSpeed: Double
    public init(staticFirst: Double, staticSecond: Double, dynamicFirst: Double, dynamicSecond: Double,
                tangentialStiffness: Double, transitionSpeed: Double) throws(ContactLawError) {
        guard staticFirst.isFinite, staticSecond.isFinite, dynamicFirst.isFinite, dynamicSecond.isFinite,
              staticFirst > 0, staticSecond > 0, dynamicFirst > 0, dynamicSecond > 0,
              dynamicFirst <= staticFirst, dynamicSecond <= staticSecond,
              tangentialStiffness.isFinite, tangentialStiffness > 0, transitionSpeed.isFinite, transitionSpeed > 0 else { throw .invalidMaterial }
        self.staticFirst=staticFirst; self.staticSecond=staticSecond; self.dynamicFirst=dynamicFirst; self.dynamicSecond=dynamicSecond
        self.tangentialStiffness=tangentialStiffness; self.transitionSpeed=transitionSpeed
    }
}
