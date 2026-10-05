public protocol ExactMotorEvolving: Sendable {
    func step(parameters: ExactMotorParameters, accepted: ExactMotorState, voltage: Double, speed: Double,
              timeStep: Double, work: inout ActuationWork) throws(ActuationError) -> ExactMotorResponse
}
