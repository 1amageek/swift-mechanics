public struct FramedPointLoad: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let point: Vector3
    public let forces: ForceParts
    public let potentialEnergy: Double?
    public init(body: EntityID, frame: EntityID, point: Vector3, forces: ForceParts,
                potentialEnergy: Double? = nil) throws(LoadError) {
        guard body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        if let energy = potentialEnergy { guard energy.isFinite else { throw .invalidInput } }
        self.body = body; self.frame = frame; self.point = point
        self.forces = forces; self.potentialEnergy = potentialEnergy
    }
    /// Transform maps source axes/origin to destination axes/origin, supplied by the frame owner.
    public func transformed(to destination: EntityID, by transform: RigidTransform) throws(LoadError) -> FramedPointLoad {
        try FramedPointLoad(body: body, frame: destination,
            point: loadCore { () throws(CoreError) in try transform.transforming(point: point) },
            forces: forces.rotated(by: transform.rotation), potentialEnergy: potentialEnergy)
    }
    public func wrench(about referencePoint: Vector3) throws(LoadError) -> SpatialWrench {
        let force = try forces.total()
        let torque = try loadCore { () throws(CoreError) in try point.subtracting(referencePoint).cross(force) }
        return SpatialWrench(torque: torque, force: force)
    }
}
