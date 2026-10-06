internal final class ConstrainedImpactCandidate: Sendable {
    let mode: ConstrainedImpactMode
    let prediction: ContactImpactPrediction
    let impulses: [Double]
    let delta: [Double]
    let velocity: [Double]
    let applied: [Double]
    let reaction: [Double]
    let after: Double
    init(mode: ConstrainedImpactMode, prediction: ContactImpactPrediction, impulses: [Double], delta: [Double],
         velocity: [Double], applied: [Double], reaction: [Double], after: Double) {
        self.mode = mode; self.prediction = prediction; self.impulses = impulses; self.delta = delta
        self.velocity = velocity; self.applied = applied; self.reaction = reaction; self.after = after
    }
}
