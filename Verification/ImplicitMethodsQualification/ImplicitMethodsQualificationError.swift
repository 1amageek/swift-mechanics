import SwiftMechanics

public enum ImplicitMethodsQualificationError: Error, Sendable {
    case unsupportedPlatform
    case assertion(String)
    case implicitStep(ImplicitIntegrationFailure)
    case structuralStep(StructuralImplicitFailure)
    case method(ImplicitMethodCause)
    case runtime(RuntimeFailure)
    case numerical(NumericalError)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case load(LoadError)
    case compilation(CompilationFailure)
    case unexpectedSupplier
}
