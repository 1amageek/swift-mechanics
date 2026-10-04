public struct ManifoldProjectionPolicy: Sendable {
    public let constraints: ConstraintSolvePolicy
    public let maximumIterations: Int
    public let maximumPathCorrection: Double
    public let metadata: String
    public init(constraints:ConstraintSolvePolicy,maximumIterations:Int,maximumPathCorrection:Double,
                maximumMetadataBytes:Int) throws(GeometricConstraintError) {
        guard maximumIterations > 0,maximumPathCorrection.isFinite,maximumPathCorrection > 0,
              constraints.diagonalMetric.allSatisfy({$0.isFinite && $0 > 0}),constraints.originalResidualTolerance.isFinite,
              constraints.originalResidualTolerance > 0 else { throw .invalidInput }
        try ManifoldArithmetic.numeric { () throws(NumericalError) -> Void in try constraints.linearCapability.validate(for:Double.self,algorithms:[.cholesky,.partialPivotLU]) }
        let count=try ManifoldArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.sum(256,try NumericalWork.product(17,constraints.diagonalMetric.count)) }
        guard count <= maximumMetadataBytes else { throw .capacityExceeded }
        var encoded="tangent-path-v1";encoded.reserveCapacity(count)
        func put(_ x:UInt64) { encoded.append(":");let raw=String(x,radix:16);encoded.append(String(repeating:"0",count:16-raw.count));encoded.append(raw) }
        put(UInt64(maximumIterations));put(maximumPathCorrection.bitPattern);put(constraints.originalResidualTolerance.bitPattern)
        put(constraints.rankRelativeTolerance.bitPattern);put(constraints.rankPolicy == .allowRedundancy ? 0 : 1)
        put(constraints.linearCapability.algorithm == .cholesky ? 0 : 1)
        put(constraints.linearTolerance.absoluteResidual.bitPattern);put(constraints.linearTolerance.relativeResidual.bitPattern);put(constraints.linearTolerance.pivotThreshold.bitPattern)
        put(UInt64(constraints.diagonalMetric.count));for metric in constraints.diagonalMetric { put(metric.bitPattern) }
        self.constraints=constraints;self.maximumIterations=maximumIterations;self.maximumPathCorrection=maximumPathCorrection;metadata=encoded
    }
}
