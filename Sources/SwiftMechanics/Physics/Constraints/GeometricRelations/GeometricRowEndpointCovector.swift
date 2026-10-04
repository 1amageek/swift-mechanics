public struct GeometricRowEndpointCovector: Equatable, Sendable {
    public let body: EntityID
    public let worldFrame: EntityID
    /// World point about which angularGradient is a pure couple covector.
    public let referencePointWorld: Vector3
    /// Inverse metres, paired with point translation; multiply by joules for continuous force.
    public let linearGradient: Vector3
    /// Dimensionless, paired with body rotation; multiply by joules for continuous torque.
    public let angularGradient: Vector3
    internal init(body: EntityID, worldFrame: EntityID, point: Vector3, linear: Vector3, angular: Vector3) {
        self.body = body; self.worldFrame = worldFrame; referencePointWorld = point
        linearGradient = linear; angularGradient = angular
    }
}
