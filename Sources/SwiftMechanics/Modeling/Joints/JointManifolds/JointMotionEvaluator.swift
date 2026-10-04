
public struct JointMotionEvaluator: JointMotionEvaluating, Sendable {
    public init() {}

    public func evaluate(_ manifold: JointManifold, q: ArraySlice<Double>, v: ArraySlice<Double>,
                         acceleration: ArraySlice<Double>, policy: JointEvaluationPolicy) throws -> JointKinematics {
        guard q.count == manifold.positionCount, v.count == manifold.velocityCount,
              acceleration.count == manifold.velocityCount else { throw JointError.invalidCoordinateCount }
        guard q.allSatisfy({ $0.isFinite }), v.allSatisfy({ $0.isFinite }),
              acceleration.allSatisfy({ $0.isFinite }) else { throw JointError.nonFiniteState }
        if manifold.kind == .spherical || manifold.kind == .sixDOF {
            return try quaternionEvaluation(manifold, q: q, v: v, acceleration: acceleration, policy: policy)
        }
        let composer = FrameMotionComposer()
        var motion = FrameMotion.stationary(pose: .identity)
        var prefixes: [RigidTransform] = []
        prefixes.reserveCapacity(manifold.velocityCount)
        for index in manifold.orderedAxes.indices {
            prefixes.append(motion.pose)
            let axis = manifold.orderedAxes[index]
            let generator = try axis.generator()
            let rate = v[v.startIndex + index], second = acceleration[acceleration.startIndex + index]
            let relative = FrameMotion(pose: try axis.pose(coordinate: q[q.startIndex + index]),
                velocity: SpatialMotion(angular: try generator.angular.scaled(by: rate), linear: try generator.linear.scaled(by: rate)),
                acceleration: SpatialMotion(angular: try generator.angular.scaled(by: second), linear: try generator.linear.scaled(by: second)))
            motion = try composer.composed(parent: motion, relative: relative)
        }
        var columns: [SpatialMotion] = []
        columns.reserveCapacity(manifold.velocityCount)
        for index in manifold.orderedAxes.indices {
            let spatial = try prefixes[index].transforming(motion: manifold.orderedAxes[index].generator())
            columns.append(SpatialMotion(angular: spatial.angular, linear: try spatial.velocity(at: motion.pose.translation)))
        }
        try validatingRank(columns, policy: policy)
        return JointKinematics(frameMotion: motion, subspace: JointMotionSubspace(columns: columns), coordinateRate: Array(v))
    }

    public func integrating(_ manifold: JointManifold, q: ArraySlice<Double>, v: ArraySlice<Double>,
                            timeStep: Double, policy: JointEvaluationPolicy) throws -> [Double] {
        guard timeStep.isFinite, timeStep >= 0 else { throw JointError.invalidTimeStep }
        let zero = [Double](repeating: 0, count: manifold.velocityCount)
        let evaluated = try evaluate(manifold, q: q, v: v, acceleration: zero[...], policy: policy)
        if manifold.kind == .spherical || manifold.kind == .sixDOF {
            let offset = manifold.kind == .spherical ? 0 : 3
            let angular = try Vector3(v[v.startIndex + offset], v[v.startIndex + offset + 1], v[v.startIndex + offset + 2])
            let rotation = try evaluated.frameMotion.pose.rotation.integratingBodyAngularVelocity(angular, timeStep: timeStep)
            let quaternion = [rotation.w, rotation.x, rotation.y, rotation.z]
            if manifold.kind == .spherical { return quaternion }
            let translation = try evaluated.frameMotion.pose.translation.adding(Vector3(v[v.startIndex], v[v.startIndex + 1], v[v.startIndex + 2]).scaled(by: timeStep))
            return [translation.x, translation.y, translation.z] + quaternion
        }
        return try q.indices.map { index in
            let value = q[index] + timeStep * v[v.startIndex + index - q.startIndex]
            guard value.isFinite else { throw JointError.nonFiniteState }
            return value
        }
    }

    private func quaternionEvaluation(_ manifold: JointManifold, q: ArraySlice<Double>, v: ArraySlice<Double>,
                                      acceleration: ArraySlice<Double>, policy: JointEvaluationPolicy) throws -> JointKinematics {
        let spherical = manifold.kind == .spherical
        let fullQ = spherical ? [0, 0, 0] + Array(q) : Array(q)
        let fullV = spherical ? [0, 0, 0] + Array(v) : Array(v)
        let state = try BaseLayout.spatialFloating.decode(BaseCoordinates(q: fullQ, v: fullV), quaternionTolerance: policy.quaternionTolerance)
        guard case .spatial(let pose, let linear, let bodyAngular) = state else { throw JointError.invalidJointGeometry }
        let offset = spherical ? 0 : 3
        let angularAcceleration = try Vector3(acceleration[acceleration.startIndex + offset], acceleration[acceleration.startIndex + offset + 1], acceleration[acceleration.startIndex + offset + 2])
        let linearAcceleration = spherical ? Vector3.zero : try Vector3(acceleration[acceleration.startIndex], acceleration[acceleration.startIndex + 1], acceleration[acceleration.startIndex + 2])
        let frame = FrameMotion(pose: pose,
                                velocity: SpatialMotion(angular: try pose.rotation.rotating(bodyAngular), linear: linear),
                                acceleration: SpatialMotion(angular: try pose.rotation.rotating(angularAcceleration), linear: linearAcceleration))
        var columns: [SpatialMotion] = []
        if !spherical {
            for axis in [Vector3.unitX, .unitY, .unitZ] { columns.append(SpatialMotion(angular: .zero, linear: axis)) }
        }
        for axis in [Vector3.unitX, .unitY, .unitZ] {
            columns.append(SpatialMotion(angular: try pose.rotation.rotating(axis), linear: .zero))
        }
        let rate = try pose.rotation.bodyRate(for: bodyAngular)
        let quaternionRate = [rate.w, rate.x, rate.y, rate.z]
        let coordinateRate = spherical ? quaternionRate : [linear.x, linear.y, linear.z] + quaternionRate
        try validatingRank(columns, policy: policy)
        return JointKinematics(frameMotion: frame, subspace: JointMotionSubspace(columns: columns), coordinateRate: coordinateRate)
    }

    private func validatingRank(_ columns: [SpatialMotion], policy: JointEvaluationPolicy) throws {
        var basis: [[Double]] = []
        basis.reserveCapacity(columns.count)
        for column in columns {
            let length = policy.characteristicLengthMeters
            var values = [column.angular.x, column.angular.y, column.angular.z,
                          column.linear.x / length, column.linear.y / length, column.linear.z / length]
            guard values.allSatisfy({ $0.isFinite }) else { throw JointError.nonFiniteState }
            let scale = values.reduce(0.0) { max($0, abs($1)) }
            guard scale > 0 else { throw JointError.chartSingularity }
            for index in values.indices { values[index] /= scale }
            let norm = values.reduce(0) { $0 + $1 * $1 }.squareRoot()
            for index in values.indices { values[index] /= norm }
            for _ in 0..<2 {
                for previous in basis {
                    var dot = 0.0
                    for index in values.indices { dot += values[index] * previous[index] }
                    for index in values.indices { values[index] -= dot * previous[index] }
                }
            }
            let residual = values.reduce(0) { $0 + $1 * $1 }.squareRoot()
            guard residual > policy.chartRankRelative else { throw JointError.chartSingularity }
            for index in values.indices { values[index] /= residual }
            basis.append(values)
        }
    }
}
