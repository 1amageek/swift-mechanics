/// Immutable original source with producer-only initialization; no event/publication authority.
public final class PreparedJointStop: Sendable {
    public let input: JointStopInput
    public let source: ObservationSource
    public let encoder: JointEncoderObservation
    public let layout: JointCoordinateLayout
    public let gaps: ScalarJointLimitResponse
    /// Normal metric rows in the original full generalized velocity order.
    public let lowerRow: [Double]
    public let upperRow: [Double]
    internal init(input: JointStopInput, source: ObservationSource, encoder: JointEncoderObservation,
                  layout: JointCoordinateLayout, gaps: ScalarJointLimitResponse, lowerRow: [Double], upperRow: [Double]) {
        self.input=input; self.source=source; self.encoder=encoder; self.layout=layout; self.gaps=gaps
        self.lowerRow=lowerRow; self.upperRow=upperRow
    }
}
