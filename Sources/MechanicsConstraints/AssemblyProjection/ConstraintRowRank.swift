import MechanicsNumerics

internal enum ConstraintRowRank {
    @inline(never)
    static func compute(rows: [Double], ids: [UInt64], metric: [Double], policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintRankEvidence {
        let n=metric.count, m=ids.count
        let mn=try ConstraintArithmetic.product(m,n)
        guard rows.count == mn else { throw .invalidDimensions }
        var basis=[Double](repeating:0,count:mn), scratch=[Double](repeating:0,count:n)
        var selected: [Int]=[], dependent: [UInt64]=[]; selected.reserveCapacity(m); dependent.reserveCapacity(m)
        for row in 0..<m {
            try ConstraintArithmetic.check(policy.evaluation)
            var original=0.0
            for i in 0..<n {
                try ConstraintArithmetic.charge(5,&work)
                scratch[i]=try ConstraintArithmetic.finite(rows[row*n+i]/metric[i].squareRoot()); original+=scratch[i]*scratch[i]
            }
            original=try ConstraintArithmetic.finite(original.squareRoot())
            for _ in 0..<2 {
                for k in selected.indices {
                    var dot=0.0
                    for i in 0..<n { try ConstraintArithmetic.charge(2,&work); dot+=scratch[i]*basis[k*n+i] }
                    for i in 0..<n { try ConstraintArithmetic.charge(2,&work); scratch[i]-=dot*basis[k*n+i] }
                }
            }
            var norm=0.0
            for i in 0..<n { try ConstraintArithmetic.charge(2,&work); norm+=scratch[i]*scratch[i] }
            try ConstraintArithmetic.charge(2,&work); norm=try ConstraintArithmetic.finite(norm.squareRoot())
            if selected.count < n, original > 0, norm > policy.rankRelativeTolerance*original {
                for i in 0..<n { try ConstraintArithmetic.charge(1,&work); basis[selected.count*n+i]=scratch[i]/norm }
                selected.append(row)
            } else { dependent.append(ids[row]) }
        }
        if case .requireIndependentRows = policy.rankPolicy, selected.count != m { throw .rankAmbiguity(rank:selected.count,rows:m) }
        return ConstraintRankEvidence(rank:selected.count,independentRows:selected,dependentRowIDs:dependent,reactionNullity:m-selected.count)
    }
}
