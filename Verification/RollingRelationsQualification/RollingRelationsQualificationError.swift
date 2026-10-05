import SwiftMechanics

public enum RollingRelationsQualificationError: Error, Sendable {
    case assertion(String)
    case rolling(RollingError)
    case compilation(CompilationFailure)
    case joints(JointError)
    case numerical(NumericalError)
    case geometry(CoreError)
    case model(ModelError)
    case unexpectedSupplier
}
