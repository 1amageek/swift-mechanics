public protocol CableRouting: Sendable {
    func evaluate(points: [RoutePoint], branch: CableBranch, coordinateRate: [Double],
                  secondDerivativeDirection: [Double], minimumSegmentLength: Double,
                  work: inout LoadWork) throws(LoadError) -> CableRouteResponse
}
