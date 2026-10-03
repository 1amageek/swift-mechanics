import MechanicsCore

public struct JointMotionSubspace: Equatable, Sendable {
    public let columns: [SpatialMotion]

    internal init(columns: [SpatialMotion]) { self.columns = columns }

    public func applying(_ velocity: ArraySlice<Double>) throws -> SpatialMotion {
        guard velocity.count == columns.count else { throw JointError.invalidCoordinateCount }
        guard velocity.allSatisfy({ $0.isFinite }) else { throw JointError.nonFiniteState }
        var angular = Vector3.zero, linear = Vector3.zero
        for index in columns.indices {
            let value = velocity[velocity.startIndex + index]
            angular = try angular.adding(columns[index].angular.scaled(by: value))
            linear = try linear.adding(columns[index].linear.scaled(by: value))
        }
        return SpatialMotion(angular: angular, linear: linear)
    }

    public func transposed(against wrench: SpatialWrench) throws -> [Double] {
        try columns.map { try wrench.power(against: $0) }
    }
}
