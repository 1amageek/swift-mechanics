public struct RigidTransform: Equatable, Sendable, SpatialTransforming {
    public let rotation: UnitQuaternion
    public let translation: Vector3

    public static let identity = RigidTransform(rotation: .identity, translation: .zero)

    /// Maps coordinates in the source frame into the destination frame.
    public init(rotation: UnitQuaternion, translation: Vector3) {
        self.rotation = rotation
        self.translation = translation
    }

    public func transforming(point: Vector3) throws(CoreError) -> Vector3 {
        try rotation.rotating(point).adding(translation)
    }

    public func transforming(direction: Vector3) throws(CoreError) -> Vector3 {
        try rotation.rotating(direction)
    }

    /// Transforms the origin-referenced velocity field, not just a body's COM velocity.
    public func transforming(motion: SpatialMotion) throws(CoreError) -> SpatialMotion {
        let angular = try rotation.rotating(motion.angular)
        let linear = try rotation.rotating(motion.linear).adding(translation.cross(angular))
        return SpatialMotion(angular: angular, linear: linear)
    }

    public func transforming(wrench: SpatialWrench) throws(CoreError) -> SpatialWrench {
        let force = try rotation.rotating(wrench.force)
        let torque = try rotation.rotating(wrench.torque).adding(translation.cross(force))
        return SpatialWrench(torque: torque, force: force)
    }

    public func composed(with sourceToIntermediate: RigidTransform) throws(CoreError) -> RigidTransform {
        RigidTransform(
            rotation: try rotation.multiplied(by: sourceToIntermediate.rotation),
            translation: try transforming(point: sourceToIntermediate.translation)
        )
    }

    public func inverted() throws(CoreError) -> RigidTransform {
        let inverseRotation = rotation.conjugated()
        return RigidTransform(
            rotation: inverseRotation,
            translation: try inverseRotation.rotating(translation).scaled(by: -1)
        )
    }
}
