public protocol SpatialTransforming: Sendable {
    func transforming(point: Vector3) throws(CoreError) -> Vector3
    func transforming(direction: Vector3) throws(CoreError) -> Vector3
    func transforming(motion: SpatialMotion) throws(CoreError) -> SpatialMotion
    func transforming(wrench: SpatialWrench) throws(CoreError) -> SpatialWrench
    func inverted() throws(CoreError) -> RigidTransform
}
