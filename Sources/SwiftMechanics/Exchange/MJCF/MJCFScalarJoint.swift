public struct MJCFScalarJoint: Sendable {
    public let binding: MJCFEntityBinding
    public let coordinate: ScalarCoordinateKind
    public let positionIndex: Int
    public let velocityIndex: Int
    public let reference: Double
    internal init(binding: MJCFEntityBinding, coordinate: ScalarCoordinateKind, positionIndex: Int, velocityIndex: Int, reference: Double) {
        self.binding = binding; self.coordinate = coordinate; self.positionIndex = positionIndex; self.velocityIndex = velocityIndex; self.reference = reference
    }
}
