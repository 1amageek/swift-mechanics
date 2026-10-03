public struct SpatialMotion: Equatable, Sendable {
    public let angular: Vector3
    public let linear: Vector3

    public init(angular: Vector3, linear: Vector3) {
        self.angular = angular
        self.linear = linear
    }

    public func velocity(at point: Vector3) throws(CoreError) -> Vector3 {
        try linear.adding(angular.cross(point))
    }
}
