public protocol CollisionSweeping: Sendable {
    func timeOfImpact(first: CollisionSweep, second: CollisionSweep, durationSeconds: Double,
                      maximumTimeWidthSeconds: Double, policy: CollisionQueryPolicy,
                      work: inout CollisionWork) throws(CollisionError) -> CollisionTOIBracket?
}
