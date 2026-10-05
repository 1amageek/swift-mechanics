internal enum RollingRowRank {
    static func compute(_ rows: [RollingConstraintRow], policy: RollingEvaluationPolicy) throws -> RollingRankEvidence {
        let count = policy.velocityScales.count
        var basis = [Double](repeating: 0, count: try NumericalWork.product(3, count))
        var scratch = [Double](repeating: 0, count: count)
        var independent: [UInt64] = [], dependent: [UInt64] = []
        independent.reserveCapacity(3); dependent.reserveCapacity(3)
        for row in rows {
            try RollingArithmetic.check(policy)
            var scale = 0.0
            for column in 0..<count {
                scratch[column] = try RollingArithmetic.finite(row.coefficients[column] * policy.velocityScales[column])
                scale = max(scale, abs(scratch[column]))
            }
            if scale == 0 { dependent.append(row.rowID); continue }
            // Scale before squaring, so a finite scaled row cannot overflow its norm silently.
            var originalSquared = 0.0
            for column in 0..<count {
                scratch[column] /= scale
                originalSquared = try RollingArithmetic.finite(originalSquared + scratch[column] * scratch[column])
            }
            for _ in 0..<2 {
                for index in independent.indices {
                    var dot = 0.0
                    for column in 0..<count { dot = try RollingArithmetic.finite(dot + scratch[column] * basis[index * count + column]) }
                    for column in 0..<count { scratch[column] = try RollingArithmetic.finite(scratch[column] - dot * basis[index * count + column]) }
                }
            }
            var squared = 0.0
            for column in 0..<count { squared = try RollingArithmetic.finite(squared + scratch[column] * scratch[column]) }
            let norm = squared.squareRoot(), threshold = policy.rankRelativeTolerance * originalSquared.squareRoot()
            if independent.count < count, norm > threshold {
                for column in 0..<count { basis[independent.count * count + column] = try RollingArithmetic.finite(scratch[column] / norm) }
                independent.append(row.rowID)
            } else { dependent.append(row.rowID) }
        }
        guard !policy.requireIndependentRows || independent.count == rows.count else {
            throw RollingError.rankDeficient(rank: independent.count, rows: rows.count)
        }
        return RollingRankEvidence(rank: independent.count, independentRowIDs: independent, dependentRowIDs: dependent)
    }
}
