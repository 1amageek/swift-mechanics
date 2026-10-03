import MechanicsCore
import MechanicsModel

public struct PointJacobian: Equatable, Sendable {
    public let body: EntityID
    public let referenceFrame: EntityID
    public let pointWorld: Vector3
    public let columns: [Vector3]
    public let prescribedDriftVelocity: Vector3

    internal init(body: EntityID, referenceFrame: EntityID, pointWorld: Vector3,
                  columns: [Vector3], prescribedDriftVelocity: Vector3) {
        self.body = body; self.referenceFrame = referenceFrame; self.pointWorld = pointWorld
        self.columns = columns; self.prescribedDriftVelocity = prescribedDriftVelocity
    }

    public func applying(_ velocities: ArraySlice<Double>) throws -> Vector3 {
        guard velocities.count == columns.count else { throw JointError.invalidCoordinateCount }
        guard velocities.allSatisfy({ $0.isFinite }) else { throw JointError.nonFiniteState }
        var result = Vector3.zero
        for index in columns.indices {
            result = try result.adding(columns[index].scaled(by: velocities[velocities.startIndex + index]))
        }
        return result
    }

    public func transposed(against force: Vector3) throws -> [Double] {
        try columns.map { try $0.dot(force) }
    }
}
