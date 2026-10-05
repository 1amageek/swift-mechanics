public struct LinearProgramFailure: Error, Sendable {
    public let cause: LinearProgramCause
    public let phase: LinearProgramPhase
    public let pivots: Int
    public let work: NumericalWork
    public let problemIdentity: String
    public let provenance: SourceProvenance
    internal init(cause: LinearProgramCause, phase: LinearProgramPhase, pivots: Int, work: NumericalWork, problem: GeneralLinearProgram) {
        self.cause = cause; self.phase = phase; self.pivots = pivots; self.work = work
        problemIdentity = problem.metadata.identity; provenance = problem.metadata.provenance
    }
}
