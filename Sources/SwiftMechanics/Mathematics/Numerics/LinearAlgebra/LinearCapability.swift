public struct LinearCapability: Equatable, Sendable {
    public let precision: NumericalPrecision
    public let backend: NumericalBackend
    public let algorithm: LinearAlgorithm
    public init(precision: NumericalPrecision, backend: NumericalBackend, algorithm: LinearAlgorithm) {
        self.precision = precision; self.backend = backend; self.algorithm = algorithm
    }
    public func validate<Scalar: NumericalScalar>(for scalar: Scalar.Type, algorithms: [LinearAlgorithm]) throws(NumericalError) {
        let expectedSignificand = precision == .float32 ? 23 : 52
        let expectedExponent = precision == .float32 ? 8 : 11
        guard Scalar.radix == 2, Scalar.significandBitCount == expectedSignificand, Scalar.exponentBitCount == expectedExponent,
              precision == Scalar.numericalPrecision, backend == .referenceCPU, algorithms.contains(algorithm) else {
            throw .unsupportedCapability
        }
    }
}
