public struct TransmissionInputDomain: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
    public init(minimum: Double, maximum: Double) throws(NonlinearTransmissionError) {
        guard minimum.isFinite, maximum.isFinite, minimum < maximum else { throw .invalidParameter(name: "inputDomain") }
        self.minimum=minimum; self.maximum=maximum
    }
    public func validate(_ input: Double) throws(NonlinearTransmissionError) {
        guard input.isFinite else { throw .invalidInput(name: "inputCoordinate") }
        guard input >= minimum, input <= maximum else {
            throw .outsideInputDomain(value: input, minimum: minimum, maximum: maximum)
        }
    }
}
