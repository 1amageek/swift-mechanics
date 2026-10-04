public protocol StationaryLoadEvaluating: Sendable {
    func evaluate(_ program:StationaryLoadProgram,catalog:StationaryLoadCatalog,physical:KinematicState,work:inout LoadWork) throws(StationaryLoadError) -> StationaryLoadSample
}
