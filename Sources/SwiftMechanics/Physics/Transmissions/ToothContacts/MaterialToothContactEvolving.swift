public protocol MaterialToothContactEvolving: Sendable {
    func initialMaterial(time: Double, q: [Double], v: [Double], policy: ToothContactPolicy,
                         work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState
    func stepMaterial(accepted: MaterialToothContactState, timeStep: Double, policy: ToothContactPolicy,
                      work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState
    func advanceMaterial(accepted: MaterialToothContactState, to time: Double, timeStep: Double, policy: ToothContactPolicy,
                         work: inout ToothContactWork) throws(MaterialToothContactFailure) -> MaterialToothContactAdvance
}
