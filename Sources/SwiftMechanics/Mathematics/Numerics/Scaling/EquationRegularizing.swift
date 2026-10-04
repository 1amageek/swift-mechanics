public protocol EquationRegularizing<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func addingDiagonal(to system: DimensionalLinearSystem<Scalar>, perturbation: [SIReferenceQuantity<Scalar>],
                        allowedMagnitude: [SIReferenceQuantity<Scalar>], budget: NumericalBudget) throws(NumericalError) -> RegularizedLinearSystem<Scalar>
}
