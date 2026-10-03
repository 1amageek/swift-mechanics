public struct CollisionTOIBracket: Sendable {
    public let lowerTime: Double
    public let upperTime: Double
    public let lowerSeparation: Double
    public let upperSeparation: Double
    public let upperWitness: CollisionWitness
    public let initialOverlap: Bool
    public let iterations: Int
}
