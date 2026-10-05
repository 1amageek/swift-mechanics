/// Initial coordinates in the supplier's joint chart, with independent q and v sizes.
public struct JointInitialState: Equatable, Sendable {
    public let coordinates: BaseCoordinates
    public let acceleration: [Double]

    public init(q: [Double], v: [Double], acceleration: [Double]) throws(MachineDefinitionFailure) {
        guard q.count <= 7, v.count <= 6, acceleration.count <= 6,
              acceleration.allSatisfy({ $0.isFinite }) else { throw .invalidJoint(.invalidCoordinateCount) }
        do { coordinates = try BaseCoordinates(q: q, v: v) }
        catch { throw .invalidBody(error) }
        self.acceleration = acceleration
    }
}
