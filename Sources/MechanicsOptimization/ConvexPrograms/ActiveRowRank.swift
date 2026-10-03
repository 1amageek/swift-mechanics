import MechanicsNumerics
internal enum ActiveRowRank {
    static func rank(rows: Int,columns: Int,buffer: inout [Double],policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) -> Int {
        var rank=0
        for column in 0..<columns {
            try OptimizationArithmetic.check(policy)
            if rank == rows { break }
            var pivot=rank, value=0.0
            for row in rank..<rows {
                try OptimizationArithmetic.charge(1,policy:policy,work:&work)
                let magnitude=abs(buffer[row*columns+column])
                if magnitude > value { pivot=row; value=magnitude }
            }
            if value == 0 { continue }
            guard value > policy.rankThreshold else { throw .rankIndeterminate(pivot:value,threshold:policy.rankThreshold) }
            if pivot != rank {
                try OptimizationArithmetic.charge(columns,policy:policy,work:&work)
                for j in 0..<columns { buffer.swapAt(pivot*columns+j,rank*columns+j) }
            }
            for row in (rank+1)..<rows {
                try OptimizationArithmetic.charge(1,policy:policy,work:&work)
                let factor=try OptimizationArithmetic.finite(buffer[row*columns+column]/buffer[rank*columns+column])
                buffer[row*columns+column]=0
                for j in (column+1)..<columns {
                    try OptimizationArithmetic.charge(2,policy:policy,work:&work)
                    buffer[row*columns+j]=try OptimizationArithmetic.finite(buffer[row*columns+j]-factor*buffer[rank*columns+j])
                }
            }
            rank += 1
        }
        return rank
    }
}
