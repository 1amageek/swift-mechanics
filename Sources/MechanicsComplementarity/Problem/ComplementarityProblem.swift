import MechanicsNumerics

/// Dimensionless convex QP/LCP input. SPD admission occurs on every solve.
public struct ComplementarityProblem: Sendable {
    public let matrix: DenseMatrix<Double>
    public let linearTerm: [Double]
    public let cone: ConeLayout
    public let identity: ComplementarityIdentity

    public init(matrix: DenseMatrix<Double>, linearTerm: [Double], cone: ConeLayout, identity: ComplementarityIdentity) throws(ComplementarityError) {
        let n = try cone.validatedDimension()
        guard matrix.rowCount == n, matrix.columnCount == n, linearTerm.count == n else { throw .numerical(.invalidDimensions) }
        guard linearTerm.allSatisfy({ $0.isFinite }) else { throw .numerical(.nonFiniteInput) }
        guard identity.coordinateIDs.count == n else { throw .invalidIdentity }
        for i in 0..<n {
            for j in 0..<i where identity.coordinateIDs[i] == identity.coordinateIDs[j] { throw .invalidIdentity }
        }
        self.matrix = matrix; self.linearTerm = linearTerm; self.cone = cone; self.identity = identity
    }
}
