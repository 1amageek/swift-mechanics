@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class GeometricVelocityContext: Sendable {
    let position:GeometricPositionContext
    let physical:NonlinearPhysicalSolveContext
    let positionEnergyChange:Double
    init(position:GeometricPositionContext,physical:NonlinearPhysicalSolveContext,positionEnergyChange:Double) {
        self.position=position;self.physical=physical;self.positionEnergyChange=positionEnergyChange
    }
}
