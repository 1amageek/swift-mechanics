public protocol NativeModelLoading: Sendable {
    func load(bytes:[UInt8],compilationPolicy:CompilationPolicy,work:inout ExchangeWork) throws(ExchangeError) -> NativeLoadedModel
}
