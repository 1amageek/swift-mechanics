public protocol ScalarLoadEvaluating: Sendable {
    func evaluate(_ law: PolynomialSpringDamper, coordinate: Double, rate: Double,
                  work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
