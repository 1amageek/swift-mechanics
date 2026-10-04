internal final class ManifoldIterationEvidence: Sendable {
    let geometry:ManifoldGeometryEvidence
    let rank:ConstraintRankEvidence
    let activeRank:ActiveCoordinateRankEvidence?
    init(geometry:ManifoldGeometryEvidence,rank:ConstraintRankEvidence,activeRank:ActiveCoordinateRankEvidence?) {
        self.geometry=geometry;self.rank=rank;self.activeRank=activeRank
    }
}
