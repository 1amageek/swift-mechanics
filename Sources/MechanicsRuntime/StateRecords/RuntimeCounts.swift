internal enum RuntimeCounts {
    static func sum(_ left: Int, _ right: Int) throws(RuntimeFailure) -> Int {
        let (value, overflow) = left.addingReportingOverflow(right)
        guard left >= 0, right >= 0, !overflow else { throw RuntimeFailure(.integerOverflow, message: "Runtime count addition overflow.") }
        return value
    }
    static func physical(q: Int, v: Int) throws(RuntimeFailure) -> Int { try sum(q, sum(v, v)) }
}
