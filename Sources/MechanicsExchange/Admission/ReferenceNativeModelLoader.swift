import MechanicsCompiler
public struct ReferenceNativeModelLoader<Compiler:MechanicalModelCompiling>: NativeModelLoading, Sendable {
    public let compiler:Compiler
    public let codec:any NativeModelCoding
    public init(compiler:Compiler,codec:any NativeModelCoding) { self.compiler=compiler;self.codec=codec }
    public func load(bytes:[UInt8],compilationPolicy:CompilationPolicy,work:inout ExchangeWork) throws(ExchangeError) -> NativeLoadedModel {
        let decoded=try codec.decode(bytes:bytes,work:&work)
        try work.checkCancellation()
        let model:CompiledMechanicalModel
        do { model=try compiler.compile(decoded.document.descriptor,policy:compilationPolicy) } catch { throw .compilation(error) }
        try work.checkCancellation()
        return NativeLoadedModel(decoded:decoded,model:model)
    }
}
