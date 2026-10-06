public enum SDFError: Error, Sendable {
    case invalidPolicy
    case invalidInput(node: Int)
    case unsupportedVersion(String)
    case missing(element: String, node: Int)
    case duplicateName(String)
    case unknownFrame(String)
    case poseCycle(String)
    case attachmentCycle(String)
    case unsupported(element: String, node: Int)
    case invalidTopology(String)
    case staleSource
    case assetRejected(String)
    case xml(XMLFailure)
    case core(CoreError)
    case model(ModelError)
    case joint(JointError)
    case load(LoadError)
    case compilation(CompilationFailure)
    case numerical(NumericalError)
    case unexpectedSupplier
}
