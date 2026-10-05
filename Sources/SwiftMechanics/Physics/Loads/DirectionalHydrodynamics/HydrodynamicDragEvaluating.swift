public protocol HydrodynamicDragEvaluating: Sendable {
    func evaluate(_ law: HydrodynamicDragLaw, body: EntityID, frame: EntityID, point: Vector3,
                  longitudinalAxis: Vector3, velocity: Vector3, mediumVelocity: Vector3,
                  work: inout LoadWork) throws(LoadError) -> HydrodynamicDragResponse
}
