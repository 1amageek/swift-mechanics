/// Portable value checkpoint. A solver validates its exact problem and scalar step.
public struct ComplementarityCache: Sendable {
    public let problem: ComplementarityProblem
    public let iterate: [Double]
    public let inverseRowBound: Double

    public init(problem: ComplementarityProblem, iterate: [Double], inverseRowBound: Double) throws(ComplementarityError) {
        guard iterate.count == problem.linearTerm.count, iterate.allSatisfy({ $0.isFinite }),
              inverseRowBound.isFinite, inverseRowBound > 0 else { throw .invalidRestart }
        self.problem = problem; self.iterate = iterate; self.inverseRowBound = inverseRowBound
    }
}
