@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class GeometricAccelerationContext: Sendable {
    let position:GeometricPositionContext
    let velocity:ConstrainedMotion
    let physical:NonlinearPhysicalSolveContext
    let energy:Double
    let positionEnergyChange:Double
    init(position:GeometricPositionContext,velocity:ConstrainedMotion,physical:NonlinearPhysicalSolveContext,energy:Double,positionEnergyChange:Double) {
        self.position=position;self.velocity=velocity;self.physical=physical;self.energy=energy;self.positionEnergyChange=positionEnergyChange
    }
}
