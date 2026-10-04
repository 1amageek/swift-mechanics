/// Supplies explicit mechanics data after original admission makes fresh anchor queries available.
@available(macOS 15, *)
public protocol CADGearRuntimeRecipeBuilding: Sendable {
    func makeRecipe(geometry: CADGeometryAdmission, time: Double)
        throws(CADGearReinitializationError) -> CADGearRuntimeRecipe
}
