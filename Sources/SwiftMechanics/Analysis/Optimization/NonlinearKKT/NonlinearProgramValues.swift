public struct NonlinearProgramValues<Scalar: NumericalScalar>: Sendable {
    public var objective: Scalar
    public var gradient: [Scalar], equalities: [Scalar], inequalities: [Scalar], equalityJacobian: [Scalar], inequalityJacobian: [Scalar]
    public init(objective: Scalar,gradient: [Scalar],equalities: [Scalar],inequalities: [Scalar],equalityJacobian: [Scalar],inequalityJacobian: [Scalar]) {
        self.objective=objective; self.gradient=gradient; self.equalities=equalities; self.inequalities=inequalities
        self.equalityJacobian=equalityJacobian; self.inequalityJacobian=inequalityJacobian
    }
}
