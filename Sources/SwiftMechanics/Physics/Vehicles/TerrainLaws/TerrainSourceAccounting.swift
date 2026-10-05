internal enum TerrainSourceAccounting {
    static func grid(_ grid: TerrainGrid, work: inout LoadWork) throws(TerrainLawError) {
        try terrainCharge(grid.source, work: &work)
        try terrainCharge(grid.terrainBody.id.key, work: &work)
        try terrainCharge(grid.material.id.key, work: &work)
        try terrainCharge(grid.referenceFrame.id.key, work: &work)
        for _ in grid.undeformedHeights { try terrainLoad { () throws(LoadError) in try work.charge(1) } }
    }
    static func calibration(_ calibration: TerrainSoilCalibration, work: inout LoadWork) throws(TerrainLawError) {
        try terrainCharge(calibration.source, work: &work)
        try terrainCharge(calibration.material.id.key, work: &work)
        try terrainCharge(TerrainSoilCalibration.formulation, work: &work)
    }
    static func history(_ history: TerrainPatchHistory, work: inout LoadWork) throws(TerrainLawError) {
        try grid(history.grid, work: &work); try calibration(history.calibration, work: &work)
        try terrainCharge(history.interfaceBody.id.key, work: &work)
        for _ in history.cells { try terrainLoad { () throws(LoadError) in try work.charge(1) } }
    }
    static func step(_ step: TerrainContactStep, work: inout LoadWork) throws(TerrainLawError) {
        try terrainCharge(step.interfaceBody.id.key, work: &work)
        try terrainCharge(step.terrainBody.id.key, work: &work)
        try terrainCharge(step.referenceFrame.id.key, work: &work)
    }
}
