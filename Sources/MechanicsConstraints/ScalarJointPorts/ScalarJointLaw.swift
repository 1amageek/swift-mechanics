public struct ScalarJointLaw: Sendable {
    public let referencePosition: Double
    public let stiffness: Double
    public let damping: Double
    public let coulombEffort: Double
    public let minimumPosition: Double
    public let maximumPosition: Double
    public init(referencePosition: Double, stiffness: Double, damping: Double, coulombEffort: Double, minimumPosition: Double, maximumPosition: Double) throws(ConstraintError) {
        guard referencePosition.isFinite, stiffness.isFinite, stiffness >= 0, damping.isFinite, damping >= 0,
              coulombEffort.isFinite, coulombEffort >= 0, minimumPosition.isFinite, maximumPosition.isFinite, minimumPosition <= maximumPosition else { throw .invalidInput }
        self.referencePosition=referencePosition; self.stiffness=stiffness; self.damping=damping; self.coulombEffort=coulombEffort
        self.minimumPosition=minimumPosition; self.maximumPosition=maximumPosition
    }
}
