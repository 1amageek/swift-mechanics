internal struct EstimatorPropagationState: Sendable {
    let time: Double, position: Double, rate: Double
    let transition: EstimatorMatrix2
}
