public protocol ControlPortPreparing: Sendable {
    func prepare(encoder: JointEncoderObservation, port: ScalarControlPort, policy: ControlPolicy,
                 work: inout NumericalWork) throws(ControlFailure) -> ScalarControlFeedback
}
