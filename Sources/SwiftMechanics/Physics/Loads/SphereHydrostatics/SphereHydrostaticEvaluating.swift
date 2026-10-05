public protocol SphereHydrostaticEvaluating: Sendable {
    /// Fluid is below the fixed plane; gravity is opposite its normalized upward normal.
    func evaluate(_ law: SphereHydrostaticLaw, body: EntityID, frame: EntityID, center: Vector3,
                  planePoint: Vector3, upwardNormal: Vector3, work: inout LoadWork) throws(LoadError) -> SphereHydrostaticResponse
}
