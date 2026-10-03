import MechanicsCore

public struct SIReferenceQuantity<Scalar: NumericalScalar>: Sendable {
    public let magnitude: Scalar
    public let dimension: PhysicalDimension
    public init(magnitude: Scalar, dimension: PhysicalDimension) throws(NumericalError) {
        guard magnitude.isFinite else { throw .nonFiniteInput }
        self.magnitude = magnitude; self.dimension = dimension
    }
}
