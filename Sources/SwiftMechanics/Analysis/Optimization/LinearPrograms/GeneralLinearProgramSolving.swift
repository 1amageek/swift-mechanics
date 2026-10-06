public protocol GeneralLinearProgramSolving: Sendable {
    func solve(_ problem: GeneralLinearProgram, policy: LinearProgramPolicy,
               work: inout NumericalWork) throws(LinearProgramFailure) -> LinearProgramResult
}
