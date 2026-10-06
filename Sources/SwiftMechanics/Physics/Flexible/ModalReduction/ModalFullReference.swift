public struct ModalFullReference: Sendable {
    public let binding: StructuralBinding
    public let time: Double
    /// Physical increments in the original full layout, including fixed coordinates.
    public let displacement: [Double]
    public init(binding: StructuralBinding, time: Double, displacement: [Double]) {
        self.binding=binding; self.time=time; self.displacement=displacement
    }
}
