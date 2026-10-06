public struct MJCFSensor: Sendable {
    public let name: String
    public let node: Int
    public let entity: EntityID
    public let kind: MJCFSensorKind
    public let targetIndex: Int
    internal init(name: String, node: Int, entity: EntityID, kind: MJCFSensorKind, targetIndex: Int) { self.name = name; self.node = node; self.entity = entity; self.kind = kind; self.targetIndex = targetIndex }
}
