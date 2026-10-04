internal struct NonlinearEvolutionInterval: Sendable {
    let time:Double
    let step:Double
    let end:Double
    let acceptedSteps:UInt64
}
