public struct StructuralResidualScale: Equatable, Sendable {
    public let dimension: PhysicalDimension
    public let referenceSI: Double
    public init(dimension: PhysicalDimension, referenceSI: Double) throws(ImplicitMethodCause) {
        guard referenceSI.isFinite, referenceSI > 0 else { throw .invalidInput }
        self.dimension = dimension; self.referenceSI = referenceSI
    }
}
