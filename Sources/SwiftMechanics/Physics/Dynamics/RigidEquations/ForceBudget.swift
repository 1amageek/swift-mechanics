public struct ForceBudget: Equatable, Sendable {
    public let gravity: [Double]
    public let actuator: [Double]
    public let applied: [Double]
    public let constraint: [Double]
    public let contact: [Double]
    public let actualPower: Double
    public let virtualPower: Double
    public let prescribedPower: Double
    internal init(gravity: [Double], actuator: [Double], applied: [Double], constraint: [Double], contact: [Double],
                  actualPower: Double, virtualPower: Double, prescribedPower: Double) {
        self.gravity = gravity; self.actuator = actuator; self.applied = applied
        self.constraint = constraint; self.contact = contact
        self.actualPower = actualPower; self.virtualPower = virtualPower; self.prescribedPower = prescribedPower
    }
    public func total(at index: Int) throws(DynamicsError) -> Double {
        guard gravity.indices.contains(index) else { throw .invalidShape }
        return try DynamicsArithmetic.finite(gravity[index]+actuator[index]+applied[index]+constraint[index]+contact[index])
    }
}
