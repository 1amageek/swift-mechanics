public struct MechanismSleepContinuationPolicy: Sendable {
    public let thresholds: MechanismSleepPolicy
    public let minimumRestDuration: Double
    public let maximumIdentityBytes: Int
    public init(thresholds: MechanismSleepPolicy, minimumRestDuration: Double, maximumIdentityBytes: Int) throws(RuntimeFailure) {
        guard minimumRestDuration.isFinite, minimumRestDuration >= 0, maximumIdentityBytes > 0 else {
            throw RuntimeFailure(.invalidInput, message:"Invalid accepted-rest duration or identity capacity.")
        }
        self.thresholds=thresholds; self.minimumRestDuration=minimumRestDuration; self.maximumIdentityBytes=maximumIdentityBytes
    }
}
