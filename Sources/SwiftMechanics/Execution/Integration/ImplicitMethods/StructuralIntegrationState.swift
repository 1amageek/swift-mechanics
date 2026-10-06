public struct StructuralIntegrationState: Sendable {
    public let descriptor: ODEDescriptor
    public let time: Double
    public let displacement: [Double]
    public let velocity: [Double]
    public let acceleration: [Double]
    public init(descriptor: ODEDescriptor, time: Double, displacement: [Double], velocity: [Double],
                acceleration: [Double]) throws(ImplicitMethodCause) {
        let n = descriptor.dimensions.count
        guard time.isFinite, displacement.count == n, velocity.count == n, acceleration.count == n,
              displacement.allSatisfy({ $0.isFinite }), velocity.allSatisfy({ $0.isFinite }),
              acceleration.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        self.descriptor = descriptor; self.time = time; self.displacement = displacement
        self.velocity = velocity; self.acceleration = acceleration
    }
}
