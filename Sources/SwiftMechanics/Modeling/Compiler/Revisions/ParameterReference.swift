
public struct ParameterReference: Equatable, Hashable, Sendable {
    public let entity: EntityID?
    public let aspect: ParameterAspect

    public init(entity: EntityID?, aspect: ParameterAspect) { self.entity = entity; self.aspect = aspect }
}
