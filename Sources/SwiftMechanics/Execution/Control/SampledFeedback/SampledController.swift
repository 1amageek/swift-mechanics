public struct SampledController: Sendable {
    public enum Law: Equatable, Sendable { case servo, computedTorque }
    public let law:Law
    public let servo:ScalarServo
    public let mode:DriveMode
    public let positionAccelerationGain:Double,rateAccelerationGain:Double
    public init(servo:ScalarServo,mode:DriveMode) {
        self.servo=servo;self.mode=mode;law = .servo;positionAccelerationGain=0;rateAccelerationGain=0
    }
    public init(effortServo:ScalarServo,positionAccelerationGain:Double,rateAccelerationGain:Double) throws(ControlFailure) {
        guard positionAccelerationGain.isFinite,rateAccelerationGain.isFinite,positionAccelerationGain >= 0,rateAccelerationGain >= 0 else { throw ControlFailure(.invalidInput,phase:"controller") }
        servo=effortServo;mode = .effort;law = .computedTorque
        self.positionAccelerationGain=positionAccelerationGain;self.rateAccelerationGain=rateAccelerationGain
    }
}
