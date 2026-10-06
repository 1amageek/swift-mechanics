public protocol TerrainLawEvaluating: Sendable {
    func initialHistory(grid: TerrainGrid, calibration: TerrainSoilCalibration,
                        footprint: TerrainRectangularFootprint, interfaceBody: ModelReference,
                        interfaceHeight: Double, timeSeconds: Double, policy: TerrainAcceptancePolicy,
                        work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory
    func evaluate(step: TerrainContactStep, accepted: TerrainPatchHistory,
                  policy: TerrainAcceptancePolicy, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchTrial
    func accept(trial: TerrainPatchTrial, replacing accepted: TerrainPatchHistory,
                work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory
    func checkpoint(accepted: TerrainPatchHistory, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchCheckpoint
    func restore(checkpoint: TerrainPatchCheckpoint, currentGrid: TerrainGrid,
                 currentCalibration: TerrainSoilCalibration, currentFootprint: TerrainRectangularFootprint,
                 currentInterfaceBody: ModelReference, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory
}
