import MechanicsCore
public struct DynamicsAdmission: Sendable {
    public let capacity: DynamicsCapacity
    public let angularVelocityTolerance: NumericalTolerance
    public let linearVelocityTolerance: NumericalTolerance
    public let isCancelled: @Sendable () -> Bool
    public init(capacity: DynamicsCapacity, angularVelocityTolerance: NumericalTolerance,
                linearVelocityTolerance: NumericalTolerance, isCancelled: @escaping @Sendable () -> Bool = { false }) {
        self.capacity = capacity; self.angularVelocityTolerance = angularVelocityTolerance
        self.linearVelocityTolerance = linearVelocityTolerance; self.isCancelled = isCancelled
    }
}
