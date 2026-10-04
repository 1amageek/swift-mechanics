/// Contains actual original producer state and Runtime RNG, never reconstructed constitutive records.
public final class GranularRuntimeContinuation: Sendable {
    public let particles: GranularState
    public let random: RuntimeRandomState
    public let gravityChoiceIndices: [UInt64]
    internal let source: GranularRuntimeSource
    internal init(source: GranularRuntimeSource, particles: GranularState, random: RuntimeRandomState, choices: [UInt64]) {
        self.source=source;self.particles=particles;self.random=random;gravityChoiceIndices=choices
    }
}
