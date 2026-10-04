public struct KinematicCapacity: Equatable, Sendable {
    public let maximumBodies: Int
    public let maximumVelocities: Int
    public let maximumJacobianScalars: Int

    public init(maximumBodies: Int, maximumVelocities: Int, maximumJacobianScalars: Int) throws(JointError) {
        guard maximumBodies >= 0, maximumVelocities >= 0, maximumJacobianScalars >= 0 else { throw .invalidPolicy }
        self.maximumBodies = maximumBodies
        self.maximumVelocities = maximumVelocities
        self.maximumJacobianScalars = maximumJacobianScalars
    }

    public func validating(bodyCount: Int, velocityCount: Int) throws(JointError) {
        guard bodyCount >= 0, velocityCount >= 0 else { throw .invalidPolicy }
        let (columns, overflow) = bodyCount.multipliedReportingOverflow(by: velocityCount)
        guard !overflow else { throw .integerOverflow }
        let (scalars, scalarOverflow) = columns.multipliedReportingOverflow(by: 6)
        guard !scalarOverflow else { throw .integerOverflow }
        guard bodyCount <= maximumBodies, velocityCount <= maximumVelocities,
              scalars <= maximumJacobianScalars else { throw .capacityExceeded }
    }
}
