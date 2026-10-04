
public struct CompiledCacheKey: Equatable, Hashable, Sendable {
    public let kind: CompiledCacheKind
    public let entity: EntityID?

    public init(kind: CompiledCacheKind, entity: EntityID?) { self.kind = kind; self.entity = entity }
}
