import MechanicsCore
public struct StraightCableRouter: CableRouting {
    public init() {}
    public func evaluate(points: [RoutePoint], branch: CableBranch, coordinateRate: [Double],
                         secondDerivativeDirection: [Double], minimumSegmentLength: Double,
                         work: inout LoadWork) throws(LoadError) -> CableRouteResponse {
        guard branch == .straightWaypoints else {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Pulley/wrapping contact and branch selection are not implemented. This route path fails until length and branch derivatives have geometry-specific behavioral evidence.
            throw .unsupportedDomain
        }
        guard points.count >= 2, minimumSegmentLength.isFinite, minimumSegmentLength > 0,
              coordinateRate.allSatisfy({ $0.isFinite }), secondDerivativeDirection.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        let n = coordinateRate.count
        guard secondDerivativeDirection.count == n else { throw .invalidShape }
        for point in points {
            guard point.frame == points[0].frame else { throw .frameMismatch }
            guard point.coordinateColumns.count == n else { throw .invalidShape }
        }
        try work.reserve(scalars: LoadWork.sum(n, LoadWork.product(3, points.count)))
        var gradient = [Double](repeating: 0, count: n), waypointGradient = [Vector3](repeating: .zero, count: points.count)
        var length = 0.0, prescribedRate = 0.0, curvature = 0.0
        for segment in 0..<(points.count - 1) {
            try work.charge(1)
            let a = points[segment], b = points[segment + 1]
            let delta = try loadCore { () throws(CoreError) in try b.position.subtracting(a.position) }
            let distance = try loadCore { () throws(CoreError) in try delta.magnitude() }
            guard distance > minimumSegmentLength else { throw .degenerateRoute }
            let unit = try loadCore { () throws(CoreError) in try delta.normalized() }
            length = try loadFinite(length + distance)
            waypointGradient[segment] = try loadCore { () throws(CoreError) in try waypointGradient[segment].subtracting(unit) }
            waypointGradient[segment + 1] = try loadCore { () throws(CoreError) in try waypointGradient[segment + 1].adding(unit) }
            prescribedRate = try loadFinite(prescribedRate + loadCore { () throws(CoreError) in try unit.dot(b.prescribedVelocity.subtracting(a.prescribedVelocity)) })
            var directionImage = Vector3.zero
            for i in 0..<n {
                try work.charge(1)
                let column = try loadCore { () throws(CoreError) in try b.coordinateColumns[i].subtracting(a.coordinateColumns[i]) }
                gradient[i] = try loadFinite(gradient[i] + loadCore { () throws(CoreError) in try unit.dot(column) })
                directionImage = try loadCore { () throws(CoreError) in try directionImage.adding(column.scaled(by: secondDerivativeDirection[i])) }
            }
            // Orthogonal projection avoids cancellation in norm^2 - parallel^2.
            let projection = try loadCore { () throws(CoreError) in try directionImage.subtracting(unit.scaled(by: unit.dot(directionImage))) }
            curvature = try loadFinite(curvature + loadCore { () throws(CoreError) in try projection.dot(projection) } / distance)
        }
        var virtualRate = 0.0
        for i in 0..<n { try work.charge(1); virtualRate = try loadFinite(virtualRate + gradient[i] * coordinateRate[i]) }
        return CableRouteResponse(frame: points[0].frame, length: length, coordinateGradient: gradient,
            waypointGradient: waypointGradient, virtualLengthRate: virtualRate, prescribedLengthRate: prescribedRate,
            directionalSecondDerivative: curvature)
    }
}
