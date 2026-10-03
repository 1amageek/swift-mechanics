public struct CollisionManifoldPolicy: Sendable {
    public let mergeDistance: Double
    public let breakingSeparation: Double
    public init(mergeDistance: Double, breakingSeparation: Double) throws(CollisionError) {
        guard mergeDistance.isFinite, mergeDistance >= 0, breakingSeparation.isFinite, breakingSeparation >= 0 else { throw .invalidPolicy }
        self.mergeDistance = mergeDistance; self.breakingSeparation = breakingSeparation
    }
}
