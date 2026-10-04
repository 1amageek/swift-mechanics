/// Owns a rich immutable geometry sample without retaining it in coordinator frames.
internal final class PlanarPrescribedRootReactionGeometry: Sendable {
    let sample: HolonomicGeometrySample
    init(_ sample: HolonomicGeometrySample) { self.sample=sample }
}
