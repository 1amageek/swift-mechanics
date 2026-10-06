public protocol ToothContactEvolving: Sendable {
    func initial(time: Double, q: [Double], v: [Double], evaluationTimeStep: Double,
                 policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothContactState
    func step(accepted: ToothContactState, timeStep: Double, policy: ToothContactPolicy,
              work: inout ToothContactWork) throws(ToothContactError) -> ToothContactState
    func advance(accepted: ToothContactState, to time: Double, timeStep: Double,
                 policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactFailure) -> ToothContactAdvance
}
