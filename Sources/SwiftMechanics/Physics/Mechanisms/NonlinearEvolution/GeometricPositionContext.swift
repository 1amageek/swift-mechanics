@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class GeometricPositionContext: Sendable {
    let initial:KinematicState
    let assembly:ManifoldAssemblyResult
    let chartCorrection:Double
    init(initial:KinematicState,assembly:ManifoldAssemblyResult,chartCorrection:Double) {
        self.initial=initial;self.assembly=assembly;self.chartCorrection=chartCorrection
    }
}
