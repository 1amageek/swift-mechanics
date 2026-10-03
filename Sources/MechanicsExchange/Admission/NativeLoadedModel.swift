import MechanicsCompiler
public struct NativeLoadedModel: Sendable {
    public let decoded:NativeDecodeResult
    public let model:CompiledMechanicalModel
}
