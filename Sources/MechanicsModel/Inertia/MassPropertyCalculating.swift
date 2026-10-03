public protocol MassPropertyCalculating: Sendable {
    func properties(of primitive: AnalyticPrimitive3D, density: Double,
                    policy: InertiaValidationPolicy) throws -> MassProperties3D
    func properties(of primitive: AnalyticPrimitive2D, arealDensity: Double) throws -> MassProperties2D
    func compound(parts: [CompoundPart3D], overlap: CompoundOverlapPolicy,
                  policy: InertiaValidationPolicy) throws -> MassProperties3D
}
