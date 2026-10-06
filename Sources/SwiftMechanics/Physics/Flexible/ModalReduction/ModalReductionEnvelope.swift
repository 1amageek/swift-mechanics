public struct ModalReductionEnvelope: Sendable {
    public let minimumTime: Double
    public let maximumTime: Double
    public let maximumAngularFrequency: Double
    public let maximumNormalizedDisplacement: Double
    public let maximumNormalizedVelocity: Double
    /// An admitted full linearized force-balance defect; this is not a truncation error certificate.
    public let maximumFullResidual: Double
    public let maximumReferenceDisplacementError: Double
    public init(minimumTime: Double, maximumTime: Double, maximumAngularFrequency: Double,
                maximumNormalizedDisplacement: Double, maximumNormalizedVelocity: Double,
                maximumFullResidual: Double, maximumReferenceDisplacementError: Double) throws(ModalReductionError) {
        guard minimumTime.isFinite, maximumTime.isFinite, maximumTime >= minimumTime,
              maximumAngularFrequency.isFinite, maximumAngularFrequency >= 0,
              maximumNormalizedDisplacement.isFinite, maximumNormalizedDisplacement > 0,
              maximumNormalizedVelocity.isFinite, maximumNormalizedVelocity > 0,
              maximumFullResidual.isFinite, maximumFullResidual >= 0,
              maximumReferenceDisplacementError.isFinite, maximumReferenceDisplacementError >= 0 else { throw .invalidInput }
        self.minimumTime=minimumTime; self.maximumTime=maximumTime; self.maximumAngularFrequency=maximumAngularFrequency
        self.maximumNormalizedDisplacement=maximumNormalizedDisplacement; self.maximumNormalizedVelocity=maximumNormalizedVelocity
        self.maximumFullResidual=maximumFullResidual; self.maximumReferenceDisplacementError=maximumReferenceDisplacementError
    }
}
