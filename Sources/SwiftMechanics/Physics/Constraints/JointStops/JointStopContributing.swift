public protocol JointStopContributing: Sendable {
    func prepare(_ input: JointStopInput, policy: JointStopPolicy,
                 work: inout NumericalWork) throws(JointStopFailure) -> PreparedJointStop
    func impact(_ prepared: PreparedJointStop, side: JointStopSide, policy: JointStopPolicy,
                work: inout NumericalWork, loadWork: inout LoadWork,
                contactWork: inout ContactWork) throws(JointStopFailure) -> JointStopImpactResult
}
