public struct ReferenceControlPortAdapter: ControlPortPreparing, Sendable {
    public init() {}
    public func prepare(encoder:JointEncoderObservation,port:ScalarControlPort,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) -> ScalarControlFeedback {
        for text in [encoder.model.identity,encoder.joint.key,encoder.parentAnchorFrame.key,port.binding.model.identity,port.binding.joint.key,port.parentAnchorFrame.key] {
            try ControlArithmetic.metadata(text,policy:policy,work:&work)
        }
        try ControlArithmetic.charge(32,work:&work,policy:policy)
        guard encoder.model == port.binding.model,encoder.joint == port.binding.joint,
              encoder.parentAnchorFrame == port.parentAnchorFrame,encoder.velocityConvention == .orderedAxisRates,
              encoder.positions.count == 1,encoder.coordinateRates.count == 1,encoder.velocities.count == 1,
              encoder.positionUnits == [.length],encoder.coordinateRateUnits == [port.rateDimension],encoder.velocityUnits == [port.rateDimension],
              encoder.positions[0].isFinite,encoder.velocities[0].isFinite,encoder.coordinateRates[0] == encoder.velocities[0],encoder.timeSeconds.isFinite else {
            throw ControlFailure(.incompatiblePort,phase:"feedback")
        }
        return ScalarControlFeedback(sourceTime:encoder.timeSeconds,position:encoder.positions[0],rate:encoder.velocities[0],port:port)
    }
}
