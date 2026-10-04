/// Local feasible manifold correction; no closest-point, stationarity or physical-work claim.
public struct ManifoldAssemblyResult: Sendable {
    public let state: KinematicState
    public let geometry: HolonomicGeometrySample
    public let originalResidual: Double
    public let pathCorrection: Double
    public let iterations: Int
    public let rank: ConstraintRankEvidence
    public let activeRank: ActiveCoordinateRankEvidence?
    public let correctionMetadata: String
    public let work: NumericalWork
    internal init(state:KinematicState,geometry:HolonomicGeometrySample,residual:Double,path:Double,iterations:Int,
                  rank:ConstraintRankEvidence,metadata:String,work:NumericalWork,activeRank:ActiveCoordinateRankEvidence? = nil) {
        self.activeRank=activeRank
        self.state=state;self.geometry=geometry;originalResidual=residual;pathCorrection=path;self.iterations=iterations
        self.rank=rank;correctionMetadata=metadata;self.work=work
    }
}
