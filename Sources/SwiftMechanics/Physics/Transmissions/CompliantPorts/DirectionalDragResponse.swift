
public struct DirectionalDragResponse: Sendable {
    public let binding: TransmissionPortBinding
    public let viscousEffort: Double
    public let dryFriction: JointFrictionResponse
    public let selectedEffort: Double?
    public let dissipativePower: Double
}
