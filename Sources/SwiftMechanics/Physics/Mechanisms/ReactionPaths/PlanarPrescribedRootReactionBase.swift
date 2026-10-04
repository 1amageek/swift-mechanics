/// Owns the original accepted root-law sample until row acceptance completes.
internal final class PlanarPrescribedRootReactionBase: Sendable {
    let sample: PrescribedBaseMotionSample
    init(_ sample: PrescribedBaseMotionSample) { self.sample=sample }
}
