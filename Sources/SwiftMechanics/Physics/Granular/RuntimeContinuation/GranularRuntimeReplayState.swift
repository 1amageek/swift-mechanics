internal final class GranularRuntimeReplayState: Sendable {
    let particles: GranularState
    let random: RuntimeRandomState
    init(particles: GranularState,random: RuntimeRandomState) {
        self.particles=particles;self.random=random
    }
}
