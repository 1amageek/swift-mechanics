import MechanicsRuntime
public struct GranularState: Sendable {
    public let model: GranularModel
    public let motions: [GranularMotion]
    public let contacts: [GranularContactState]
    public let random: RuntimeRandomState
    public let timeSeconds: Double
    public let steps: UInt64
    internal init(model: GranularModel, motions: [GranularMotion], contacts: [GranularContactState], random: RuntimeRandomState, timeSeconds: Double, steps: UInt64) {
        self.model=model; self.motions=motions; self.contacts=contacts; self.random=random; self.timeSeconds=timeSeconds; self.steps=steps
    }
}
