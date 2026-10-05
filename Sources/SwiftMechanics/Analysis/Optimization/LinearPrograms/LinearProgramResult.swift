public struct LinearProgramResult: Sendable {
    public let problem: GeneralLinearProgram
    public let status: LinearProgramStatus
    public let pivots: Int
    public let numericalWork: NumericalWork
    public let uniquenessEstablished = false
    internal init(problem: GeneralLinearProgram, status: LinearProgramStatus, pivots: Int, numericalWork: NumericalWork) {
        self.problem = problem; self.status = status; self.pivots = pivots; self.numericalWork = numericalWork
    }
}
