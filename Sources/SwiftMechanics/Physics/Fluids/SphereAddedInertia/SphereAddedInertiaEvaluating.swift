public protocol SphereAddedInertiaEvaluating: Sendable {
    func evaluate(law: SphereAddedInertiaLaw, bodyVelocity: Vector3, bodyAcceleration: Vector3,
                  fluidVelocity: Vector3, fluidAcceleration: Vector3, work: inout LoadWork) throws(LoadError) -> SphereAddedInertiaResponse
}
