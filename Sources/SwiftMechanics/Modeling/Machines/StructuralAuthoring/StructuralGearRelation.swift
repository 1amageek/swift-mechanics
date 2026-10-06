public struct StructuralGearRelation: Sendable {
    public let id: EntityID
    public let rowID: UInt64
    public let first: EntityID
    public let second: EntityID
    public let firstTeeth: UInt32
    public let secondTeeth: UInt32
    public let phaseRadians: Double
    public let phaseScaleRadians: Double
    public let internalMesh: Bool
    internal init(id: EntityID, rowID: UInt64, first: EntityID, second: EntityID,
                  firstTeeth: UInt32, secondTeeth: UInt32, phaseRadians: Double,
                  phaseScaleRadians: Double, internalMesh: Bool) {
        self.id = id; self.rowID = rowID; self.first = first; self.second = second
        self.firstTeeth = firstTeeth; self.secondTeeth = secondTeeth
        self.phaseRadians = phaseRadians; self.phaseScaleRadians = phaseScaleRadians
        self.internalMesh = internalMesh
    }
}
