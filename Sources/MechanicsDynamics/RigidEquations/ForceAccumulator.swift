internal struct ForceAccumulator {
    var gravity: [Double]
    var actuator: [Double]
    var applied: [Double]
    var constraint: [Double]
    var contact: [Double]
    var actualPower = 0.0
    var virtualPower = 0.0
    var prescribedPower = 0.0
    init(count: Int) {
        gravity = [Double](repeating:0,count:count); actuator = [Double](repeating:0,count:count)
        applied = [Double](repeating:0,count:count); constraint = [Double](repeating:0,count:count); contact = [Double](repeating:0,count:count)
    }
    mutating func add(_ value: Double, at index: Int, channel: ForceChannel) throws(DynamicsError) {
        switch channel {
        case .actuator: actuator[index] = try DynamicsArithmetic.finite(actuator[index]+value)
        case .applied: applied[index] = try DynamicsArithmetic.finite(applied[index]+value)
        case .constraint: constraint[index] = try DynamicsArithmetic.finite(constraint[index]+value)
        case .contact: contact[index] = try DynamicsArithmetic.finite(contact[index]+value)
        }
    }
    func result() -> ForceBudget {
        ForceBudget(gravity:gravity,actuator:actuator,applied:applied,constraint:constraint,contact:contact,
            actualPower:actualPower,virtualPower:virtualPower,prescribedPower:prescribedPower)
    }
}
