/// Source sleep and law retirement, issued only by the original source owner.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class PreparedSleepTopologyRetirement: Sendable {
    public let source:RuntimeAcceptedState
    public let release:SubtreeRelease
    public let sleepRecord:RuntimeContributorState
    public let history:MechanismSleepHistory
    public let retiredConstraintIDs:[UInt64]
    public let retiredEffort:Double
    public let targetConstraints:QuadraticConstraintSystem
    public let targetVelocityLayout:ConstraintCoordinateLayout
    public let targetDrive:[Double]
    public let sourceLawSignature:[UInt8]
    internal init(admission:_SleepTopologyRetirementAdmission) {
        source=admission.source;release=admission.release;sleepRecord=admission.record;history=admission.history
        retiredConstraintIDs=admission.retired;retiredEffort=admission.effort;targetConstraints=admission.constraints
        targetVelocityLayout=admission.layout;targetDrive=admission.drive;sourceLawSignature=admission.signature
    }
}
