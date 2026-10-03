public protocol ComplementaritySolving: Sendable {
    func solve(_ problem: ComplementarityProblem, policy: ComplementarityPolicy, warmStart: ComplementarityCache?) throws(ComplementarityError) -> ComplementaritySolution
}
