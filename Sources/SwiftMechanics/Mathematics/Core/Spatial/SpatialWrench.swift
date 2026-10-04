public struct SpatialWrench: Equatable, Sendable {
    public let torque: Vector3
    public let force: Vector3

    public init(torque: Vector3, force: Vector3) {
        self.torque = torque
        self.force = force
    }

    public func power(against motion: SpatialMotion) throws(CoreError) -> Double {
        let value = try torque.dot(motion.angular) + force.dot(motion.linear)
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
