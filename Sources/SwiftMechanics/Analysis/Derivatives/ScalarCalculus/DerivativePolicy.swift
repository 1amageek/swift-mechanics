public struct DerivativePolicy: Sendable {
    public let maximumBodies: Int
    public let maximumVelocities: Int
    public let maximumJacobianColumns: Int
    public let tolerance: NumericalTolerance
    public let residualTolerance: NumericalTolerance
    public let physicalNeighborhood: Double
    public let inertiaValidation: InertiaValidationPolicy
    public let isCancelled: @Sendable () -> Bool
    public init(maximumBodies: Int, maximumVelocities: Int, maximumJacobianColumns: Int,
                tolerance: NumericalTolerance, residualTolerance: NumericalTolerance, physicalNeighborhood: Double,
                inertiaValidation: InertiaValidationPolicy, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(DerivativeError) {
        guard maximumBodies > 0, maximumVelocities > 0, maximumJacobianColumns > 0,
              physicalNeighborhood.isFinite, physicalNeighborhood > 0 else { throw .invalidInput }
        self.maximumBodies=maximumBodies; self.maximumVelocities=maximumVelocities; self.maximumJacobianColumns=maximumJacobianColumns
        self.tolerance=tolerance; self.residualTolerance=residualTolerance; self.physicalNeighborhood=physicalNeighborhood; self.inertiaValidation=inertiaValidation; self.isCancelled=isCancelled
    }
}
