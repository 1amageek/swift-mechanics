import MechanicsConstraints

public struct ShaftLaw: Sendable {
    public let rotationalInertia: Double
    public let passive: ScalarJointLaw
    public init(rotationalInertia: Double, passive: ScalarJointLaw) throws(TransmissionError) {
        guard rotationalInertia.isFinite, rotationalInertia > 0, passive.coulombEffort == 0 else { throw .invalidInput }
        self.rotationalInertia=rotationalInertia; self.passive=passive
    }
}
