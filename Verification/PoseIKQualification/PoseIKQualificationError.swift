import SwiftMechanics

public enum PoseIKQualificationError: Error, Sendable {
    case assertion(String)
    case pose(PoseIKFailure)
    case admission(PoseIKError)
    case equation(NonlinearCause)
    case compilation(CompilationFailure)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case constraint(ConstraintError)
    case derivative(DerivativeError)
    case numerical(NumericalError)
    case unexpectedSupplier
}
