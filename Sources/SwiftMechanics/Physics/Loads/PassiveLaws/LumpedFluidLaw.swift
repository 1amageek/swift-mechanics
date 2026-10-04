public struct LumpedFluidLaw: Equatable, Sendable {
    public let linearDrag: Double
    public let quadraticDrag: Double
    public let displacedVolume: Double
    public let maximumRelativeSpeed: Double
    public init(linearDrag: Double, quadraticDrag: Double, displacedVolume: Double,
                maximumRelativeSpeed: Double) throws(LoadError) {
        guard linearDrag.isFinite, quadraticDrag.isFinite, displacedVolume.isFinite, maximumRelativeSpeed.isFinite,
              linearDrag >= 0, quadraticDrag >= 0, displacedVolume >= 0, maximumRelativeSpeed >= 0 else { throw .invalidPassiveLaw }
        self.linearDrag = linearDrag; self.quadraticDrag = quadraticDrag
        self.displacedVolume = displacedVolume; self.maximumRelativeSpeed = maximumRelativeSpeed
    }
}
