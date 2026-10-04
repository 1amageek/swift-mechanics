
public struct DimensionalLinearSystem<Scalar: NumericalScalar>: Sendable {
    public let matrix: DenseMatrix<Scalar>
    public let rightHandSide: [Scalar]
    public let equationDimensions: [PhysicalDimension]
    public let unknownDimensions: [PhysicalDimension]
    public init(matrix: DenseMatrix<Scalar>, rightHandSide: [Scalar], equationDimensions: [PhysicalDimension], unknownDimensions: [PhysicalDimension]) throws(NumericalError) {
        guard rightHandSide.count == matrix.rowCount, equationDimensions.count == matrix.rowCount,
              unknownDimensions.count == matrix.columnCount else { throw .invalidDimensions }
        guard rightHandSide.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        self.matrix = matrix; self.rightHandSide = rightHandSide
        self.equationDimensions = equationDimensions; self.unknownDimensions = unknownDimensions
    }
    public func coefficientDimension(row: Int, column: Int) throws(NumericalError) -> PhysicalDimension {
        guard row >= 0, row < matrix.rowCount, column >= 0, column < matrix.columnCount else { throw .invalidIndex }
        let numerator = equationDimensions[row], denominator = unknownDimensions[column]
        func subtract(_ a: Int8, _ b: Int8) throws(NumericalError) -> Int8 {
            let (value, overflow) = a.subtractingReportingOverflow(b)
            guard !overflow else { throw .dimensionMismatch }
            return value
        }
        return try PhysicalDimension(length: subtract(numerator.length, denominator.length), mass: subtract(numerator.mass, denominator.mass),
            time: subtract(numerator.time, denominator.time), angle: subtract(numerator.angle, denominator.angle),
            electricCurrent: subtract(numerator.electricCurrent, denominator.electricCurrent), temperature: subtract(numerator.temperature, denominator.temperature),
            amount: subtract(numerator.amount, denominator.amount), luminousIntensity: subtract(numerator.luminousIntensity, denominator.luminousIntensity))
    }
}
