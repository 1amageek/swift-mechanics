
public struct KinematicJacobianCalculator: KinematicJacobianComputing, Sendable {
    public init() {}

    public func geometric(body: EntityID, snapshot: KinematicSnapshot) throws -> KinematicJacobian {
        let state = try snapshot.body(body)
        return KinematicJacobian(body: body, referenceFrame: state.worldFrame, referencePointWorld: state.motion.pose.translation,
                                 convention: .geometricAtBodyOrigin, columns: Array(try snapshot.geometricColumns(body: body)),
                                 prescribedDrift: state.prescribedDriftVelocity)
    }

    public func spatial(body: EntityID, snapshot: KinematicSnapshot) throws -> KinematicJacobian {
        let state = try snapshot.body(body), position = state.motion.pose.translation
        let columns = try snapshot.geometricColumns(body: body).map {
            SpatialMotion(angular: $0.angular, linear: try $0.linear.subtracting($0.angular.cross(position)))
        }
        let drift = state.prescribedDriftVelocity
        return KinematicJacobian(body: body, referenceFrame: state.worldFrame, referencePointWorld: .zero,
                                 convention: .spatialAtWorldOrigin, columns: columns,
                                 prescribedDrift: SpatialMotion(angular: drift.angular, linear: try drift.linear.subtracting(drift.angular.cross(position))))
    }

    public func point(body: EntityID, bodyLocalPoint: Vector3, snapshot: KinematicSnapshot) throws -> PointJacobian {
        let state = try snapshot.body(body)
        let offset = try state.motion.pose.rotation.rotating(bodyLocalPoint)
        let position = try state.motion.pose.translation.adding(offset)
        let columns = try snapshot.geometricColumns(body: body).map { try $0.linear.adding($0.angular.cross(offset)) }
        let drift = state.prescribedDriftVelocity
        return PointJacobian(body: body, referenceFrame: state.worldFrame, pointWorld: position, columns: columns,
                             prescribedDriftVelocity: try drift.linear.adding(drift.angular.cross(offset)))
    }

    public func pointMotion(body: EntityID, bodyLocalPoint: Vector3, snapshot: KinematicSnapshot) throws -> PointKinematics {
        let state = try snapshot.body(body), frame = state.motion
        let offset = try frame.pose.rotation.rotating(bodyLocalPoint)
        let centripetal = try frame.velocity.angular.cross(frame.velocity.angular.cross(offset))
        let drift = state.prescribedDriftVelocity, bias = state.accelerationBias
        return PointKinematics(body: body, referenceFrame: state.worldFrame,
            position: try frame.pose.translation.adding(offset),
            velocity: try frame.velocity.linear.adding(frame.velocity.angular.cross(offset)),
            acceleration: try frame.acceleration.linear.adding(frame.acceleration.angular.cross(offset)).adding(centripetal),
            accelerationBias: try bias.linear.adding(bias.angular.cross(offset)).adding(centripetal),
            prescribedDriftVelocity: try drift.linear.adding(drift.angular.cross(offset)))
    }
}
