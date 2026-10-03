import MechanicsCore
import MechanicsModel

public struct KinematicJacobian: Equatable, Sendable {
    public let body: EntityID
    public let referenceFrame: EntityID
    public let referencePointWorld: Vector3
    public let convention: JacobianConvention
    public let columns: [SpatialMotion]
    public let prescribedDrift: SpatialMotion

    internal init(body: EntityID, referenceFrame: EntityID, referencePointWorld: Vector3,
                  convention: JacobianConvention, columns: [SpatialMotion], prescribedDrift: SpatialMotion) {
        self.body = body; self.referenceFrame = referenceFrame; self.referencePointWorld = referencePointWorld
        self.convention = convention; self.columns = columns; self.prescribedDrift = prescribedDrift
    }

    public func applying(_ velocities: ArraySlice<Double>) throws -> SpatialMotion {
        try JointMotionSubspace(columns: columns).applying(velocities)
    }

    public func transposed(against wrench: SpatialWrench) throws -> [Double] {
        try JointMotionSubspace(columns: columns).transposed(against: wrench)
    }
}
