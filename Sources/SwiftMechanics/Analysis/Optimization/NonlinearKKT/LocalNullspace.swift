internal struct LocalNullspace: Sendable {
    let basis: [Double],dimension: Int,residual: Double
    @inline(never)
    static func build(_ c: [Double],rows: Int,n: Int,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationCause) -> LocalNullspace {
        try LocalKKTArithmetic.charge(c.count+n,policy:policy,work:&work)
        var reduced=c,pivots=[Int](),rank=0
        pivots.reserveCapacity(min(rows,n))
        for j in 0..<n {
            if rank == rows { break }
            var chosen=rank,magnitude=0.0
            for i in rank..<rows { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); let a=abs(reduced[i*n+j]); if a > magnitude { magnitude=a; chosen=i } }
            if magnitude == 0 { continue }
            guard magnitude > policy.rankThreshold else { throw .rankIndeterminate(pivot:magnitude,threshold:policy.rankThreshold) }
            try LocalKKTArithmetic.charge(n,policy:policy,work:&work)
            if chosen != rank { for k in 0..<n { reduced.swapAt(chosen*n+k,rank*n+k) } }
            let divisor=reduced[rank*n+j]
            for k in j..<n { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); reduced[rank*n+k]=try LocalKKTArithmetic.finite(reduced[rank*n+k]/divisor) }
            for i in 0..<rows where i != rank {
                let factor=reduced[i*n+j]
                for k in j..<n { try LocalKKTArithmetic.charge(2,policy:policy,work:&work); reduced[i*n+k]=try LocalKKTArithmetic.finite(reduced[i*n+k]-factor*reduced[rank*n+k]) }
            }
            pivots.append(j); rank += 1
        }
        guard rank == rows else { throw .rankDeficient(rank:rank,rows:rows) }
        let free=n-rank
        try LocalKKTArithmetic.charge(try LocalKKTArithmetic.product(n,free),policy:policy,work:&work)
        var basis=[Double](repeating:0,count:try LocalKKTArithmetic.product(n,free)),column=0
        for j in 0..<n {
            var isPivot=false
            for p in pivots { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); if p == j { isPivot=true; break } }
            if !isPivot {
                basis[j*free+column]=1
                for i in 0..<rank { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); basis[pivots[i]*free+column] = -reduced[i*n+j] }
                column += 1
            }
        }
        var residual=0.0
        for i in 0..<rows { for j in 0..<free {
            var value=0.0
            for k in 0..<n { try LocalKKTArithmetic.charge(2,policy:policy,work:&work); value=try LocalKKTArithmetic.finite(value+c[i*n+k]*basis[k*free+j]) }
            residual=max(residual,abs(value))
        } }
        guard residual <= policy.nullspaceTolerance else { throw .certificateRejected }
        return LocalNullspace(basis:basis,dimension:free,residual:residual)
    }
}
