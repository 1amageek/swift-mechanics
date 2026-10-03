public protocol EquationScaling<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func scale(_ system: DimensionalLinearSystem<Scalar>, rowReferences: [SIReferenceQuantity<Scalar>],
               columnReferences: [SIReferenceQuantity<Scalar>], budget: NumericalBudget) throws(NumericalError) -> ScaledLinearSystem<Scalar>
}
