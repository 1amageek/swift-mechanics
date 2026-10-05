import SwiftMechanics

public enum TimeParameterizationQualificationError: Error, Sendable {
    case assertion(String)
    case retiming(RetimingError)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case dynamics(DynamicsError)
    case numerical(NumericalError)
    case load(LoadError)
    case unexpectedSupplier
}
