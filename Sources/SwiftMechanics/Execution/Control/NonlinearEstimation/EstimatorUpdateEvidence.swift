internal struct EstimatorUpdateEvidence: Sendable {
    let position: Double, rate: Double
    let covariance: EstimatorMatrix2
    let innovation: Double?, innovationVariance: Double?, normalizedSquared: Double?
    let gain: [Double]?
    let lastObservationSequence: UInt64?
}
