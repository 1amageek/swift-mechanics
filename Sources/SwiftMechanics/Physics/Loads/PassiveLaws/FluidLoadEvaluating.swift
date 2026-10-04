public protocol FluidLoadEvaluating: Sendable {
    func evaluate(_ law: LumpedFluidLaw, medium: LumpedMedium, body: EntityID, frame: EntityID,
                  centerOfBuoyancyAndDrag: Vector3, velocity: Vector3, work: inout LoadWork) throws(LoadError) -> FluidLoadResponse
}
