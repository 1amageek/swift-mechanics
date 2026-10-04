import SwiftMechanics

/// Retains actual public state and bytes across independently invoked replay phases.
final class GranularRuntimeReplayEvidence: Sendable {
    let checkpoint: [UInt8]
    let accepted: RuntimeAcceptedState
    let particles: GranularState
    let final: [UInt8]

    init(checkpoint: [UInt8], accepted: RuntimeAcceptedState, particles: GranularState, final: [UInt8]) {
        self.checkpoint = checkpoint
        self.accepted = accepted
        self.particles = particles
        self.final = final
    }
}
