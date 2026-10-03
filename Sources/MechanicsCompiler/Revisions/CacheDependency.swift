public struct CacheDependency: Equatable, Sendable {
    public let cache: CompiledCacheKey
    public let inputs: [ParameterReference]

    public init(cache: CompiledCacheKey, inputs: [ParameterReference]) { self.cache = cache; self.inputs = inputs }
}
