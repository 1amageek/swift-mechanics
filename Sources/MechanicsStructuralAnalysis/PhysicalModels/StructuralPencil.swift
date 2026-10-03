public struct StructuralPencil: Sendable {
    public let binding: StructuralBinding
    public let mass: [Double]
    public let stiffness: [Double]
    public let damping: [Double]
    public var count: Int { binding.retainedCoordinates.count }
    internal init(binding: StructuralBinding, mass: [Double], stiffness: [Double], damping: [Double]) {
        self.binding=binding;self.mass=mass;self.stiffness=stiffness;self.damping=damping
    }
}
