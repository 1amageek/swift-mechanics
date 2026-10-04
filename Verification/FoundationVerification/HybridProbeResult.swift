import SwiftMechanics

final class HybridProbeResult: Sendable {
    let result: HybridEvolutionResult
    init(_ result: HybridEvolutionResult) { self.result = result }
}
