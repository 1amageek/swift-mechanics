internal struct LoadedSleepRestProof: Sendable {
    let position:[Double]
    let drive:[Double]
    let selection:StationaryLoadSelection
    let groups:[[Int]]
}
