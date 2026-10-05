public struct AttachmentConstraintRow: Sendable {
    public let attachment: String
    public let direction: Vector3
    public let gap: Double
    public let rate: Double
    public let accelerationBias: Double
    public let prescribedRate: Double
    /// Rigid generalized velocities followed by xyz nodal velocities in the retained node order.
    public let columns: [Double]

    internal init(attachment: String, direction: Vector3, gap: Double, rate: Double,
                  accelerationBias: Double, prescribedRate: Double, columns: [Double]) {
        self.attachment = attachment; self.direction = direction; self.gap = gap; self.rate = rate
        self.accelerationBias = accelerationBias; self.prescribedRate = prescribedRate; self.columns = columns
    }
}
