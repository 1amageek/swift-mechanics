public struct ExactMotorState: Equatable, Sendable {
    public let parameters: ExactMotorParameters, time: Double, current: Double
    public init(parameters: ExactMotorParameters, time: Double, current: Double) throws(ActuationError) {
        guard time.isFinite, time >= 0, current.isFinite, abs(current) <= parameters.maximumCurrent else { throw .invalidInput }
        self.parameters = parameters; self.time = time; self.current = current
    }
}
