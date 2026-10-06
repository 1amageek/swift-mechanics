import SwiftMechanics

public enum NonlinearEstimationQualificationError: Error, Sendable {
    case assertion(String)
    case estimator(NonlinearEstimatorFailure)
    case cause(NonlinearEstimatorCause)
    case compilation(CompilationFailure)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case numerical(NumericalError)
    case load(LoadError)
    case observation(ObservationError)
    case derivative(DerivativeError)
    case dynamics(DynamicsError)
    case unexpectedSupplier
}
