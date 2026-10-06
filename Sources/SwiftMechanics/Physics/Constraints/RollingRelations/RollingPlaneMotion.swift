internal struct RollingPlaneMotion {
    let body: EntityID?
    let frame: EntityID
    let sourceID: String?
    let sourceRevision: UInt64?
    let pointLocal: Vector3
    let normalLocal: Vector3
    let motion: FrameMotion

    static func make(_ relation: RollingRelation, snapshot: KinematicSnapshot,
                     sample: RollingPrescribedPlaneSample?) throws -> Self {
        switch relation.plane {
        case .body(let body, let frame, let point, let normal):
            guard body.kind == .body, frame.kind == .frame else { throw RollingError.invalidInput }
            guard sample == nil, body != relation.wheel.body else { throw RollingError.unsupportedDomain }
            let state = try snapshot.body(body)
            guard state.bodyFrame == frame else { throw RollingError.unsupportedDomain }
            return Self(body: body, frame: frame, sourceID: nil, sourceRevision: nil, pointLocal: point,
                normalLocal: try normal.normalized(), motion: state.motion)
        case .prescribed(let frame, let sourceID, let sourceRevision, let point, let normal):
            guard frame.kind == .frame, frame != snapshot.tree.worldFrame, !sourceID.isEmpty else { throw RollingError.invalidInput }
            guard !snapshot.frames.contains(where: { $0.frame == frame }) else { throw RollingError.unsupportedDomain }
            guard let sample, sample.sourceID == sourceID, sample.sourceRevision == sourceRevision,
                  sample.modelStamp == relation.model.stamp, sample.frame == frame,
                  sample.worldFrame == snapshot.tree.worldFrame, sample.time == snapshot.time else {
                throw RollingError.stalePlaneSample
            }
            return Self(body: nil, frame: frame, sourceID: sourceID, sourceRevision: sourceRevision, pointLocal: point,
                normalLocal: try normal.normalized(), motion: sample.motion)
        }
    }

    func contact(local: Vector3, snapshot: KinematicSnapshot,
                 calculator: KinematicJacobianCalculator) throws -> RollingPointMotion {
        if let body {
            let point = try calculator.pointMotion(body: body, bodyLocalPoint: local, snapshot: snapshot)
            let jacobian = try calculator.point(body: body, bodyLocalPoint: local, snapshot: snapshot)
            return RollingPointMotion(velocity: point.velocity, acceleration: point.acceleration,
                accelerationBias: point.accelerationBias, drift: point.prescribedDriftVelocity, columns: jacobian.columns)
        }
        let offset = try motion.pose.rotation.rotating(local), angular = motion.velocity.angular
        let velocity = try motion.velocity.linear.adding(angular.cross(offset))
        let acceleration = try motion.acceleration.linear.adding(motion.acceleration.angular.cross(offset))
            .adding(angular.cross(angular.cross(offset)))
        return RollingPointMotion(velocity: velocity, acceleration: acceleration, accelerationBias: acceleration,
            drift: velocity, columns: [Vector3](repeating: .zero, count: snapshot.tree.layout.velocityCount))
    }
}
