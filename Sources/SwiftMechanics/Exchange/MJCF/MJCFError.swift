public enum MJCFError: Error, Sendable {
    case invalidPolicy
    case invalidInput(node: Int, field: String)
    case missingField(node: Int, field: String)
    case duplicate(node: Int, name: String)
    case danglingReference(node: Int, name: String)
    case unsupported(node: Int, feature: String)
    case lossNotSelected(node: Int, category: MJCFLossCategory)
    case identityMismatch
    case originalResidualMismatch(node: Int)
    case arithmeticOverflow
    case capacityExceeded
    case workExhausted
    case cancelled
    case nonFiniteArithmetic
    case producerRejected(node: Int)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case xml(XMLFailure)
    case compilation(CompilationFailure)
    case actuation(ActuationError)
    case constraints(ConstraintError)
    case native(ExchangeError)
    case load(LoadError)
}
