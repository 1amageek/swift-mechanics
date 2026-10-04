public struct TransmissionResponse: Equatable, Sendable {
    public let efforts:[Double]
    public let virtualPower:Double,prescribedPower:Double,actualPower:Double,balanceResidual:Double
    internal init(efforts:[Double],virtualPower:Double,prescribedPower:Double,actualPower:Double,balanceResidual:Double) {
        self.efforts=efforts;self.virtualPower=virtualPower;self.prescribedPower=prescribedPower;self.actualPower=actualPower;self.balanceResidual=balanceResidual
    }
}
