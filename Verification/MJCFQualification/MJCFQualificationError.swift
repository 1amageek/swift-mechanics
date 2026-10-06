import SwiftMechanics

public enum MJCFQualificationError: Error, Sendable {
    case assertion(String)
    case mjcf(MJCFError)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case compilation(CompilationFailure)
    case xml(XMLFailure)
    case actuation(ActuationError)
    case numerical(NumericalError)
    case exchange(ExchangeError)
    case unexpectedSupplier
}
