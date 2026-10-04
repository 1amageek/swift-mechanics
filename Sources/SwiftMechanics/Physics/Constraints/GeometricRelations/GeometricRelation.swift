public struct GeometricRelation: Equatable, Sendable {
    public enum Kind: UInt64, Sendable { case coincidence = 1, distance = 2, alignedAxes = 3 }
    public let kind: Kind
    public let rowIDs: [UInt64]
    public let first: GeometricFrameEndpoint
    public let second: GeometricFrameEndpoint
    public let target: GeometricAnalyticTarget
    public let scale: Double
    public let axisSign: Double
    public let transverseFirst: Vector3
    public let transverseSecond: Vector3
    public init(kind: Kind, rowIDs: [UInt64], first: GeometricFrameEndpoint, second: GeometricFrameEndpoint,
                target: GeometricAnalyticTarget, scale: Double, axisSign: Double = 1) throws(GeometricConstraintError) {
        guard rowIDs.count == (kind == .distance ? 1 : (kind == .alignedAxes ? 2 : 3)), scale.isFinite, scale > 0,
              axisSign == 1 || axisSign == -1 else { throw .invalidInput }
        if kind == .distance {
            guard target.value.x > 0,target.value.y == 0,target.value.z == 0,
                  target.rate.y == 0,target.rate.z == 0,target.second.y == 0,target.second.z == 0 else { throw .invalidInput }
        }
        if kind == .alignedAxes { guard target.value == .zero,!target.isExplicitTime,scale == 1 else { throw .invalidInput } }
        if kind == .alignedAxes {
            let axis=second.axis,seed:Vector3
            if abs(axis.x) <= min(abs(axis.y),abs(axis.z)) { seed = .unitX }
            else if abs(axis.y) <= abs(axis.z) { seed = .unitY } else { seed = .unitZ }
            let firstBasis=try GeometricArithmetic.geometry { try axis.cross(seed).normalized() }
            let secondBasis=try GeometricArithmetic.geometry { try axis.cross(firstBasis).normalized() }
            transverseFirst=firstBasis;transverseSecond=secondBasis
        } else { transverseFirst = .zero;transverseSecond = .zero }
        self.kind=kind;self.rowIDs=rowIDs;self.first=first;self.second=second;self.target=target;self.scale=scale;self.axisSign=axisSign
    }
}
