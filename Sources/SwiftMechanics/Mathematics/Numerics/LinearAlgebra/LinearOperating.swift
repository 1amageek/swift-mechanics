public protocol LinearOperating<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    var rowCount: Int { get }
    var columnCount: Int { get }
    func applying(_ vector: [Scalar], budget: NumericalBudget) throws(NumericalError) -> [Scalar]
}
