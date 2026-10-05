public struct BekkerJanosiTerrainLaw: TerrainLawEvaluating {
    public init() {}

    public func initialHistory(grid: TerrainGrid, calibration: TerrainSoilCalibration,
                               footprint: TerrainRectangularFootprint, interfaceBody: ModelReference,
                               interfaceHeight: Double, timeSeconds: Double, policy: TerrainAcceptancePolicy,
                               work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory {
        try terrainReserve(base: 256, perCell: 16, cells: grid.undeformedHeights.count, work: &work)
        try TerrainSourceAccounting.grid(grid, work: &work)
        try TerrainSourceAccounting.calibration(calibration, work: &work)
        try terrainCharge(interfaceBody.id.key, work: &work)
        guard interfaceBody.id.kind == .body, interfaceBody.id != grid.terrainBody.id,
              interfaceHeight.isFinite, timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        guard grid.material == calibration.material else { throw .staleSource }
        guard footprint.width >= calibration.domain.minimumFootprintWidth,
              footprint.width <= calibration.domain.maximumFootprintWidth else { throw .outsideCalibratedDomain }
        let maxX = try terrainFinite(grid.minimumX + Double(grid.columns) * grid.cellWidth)
        let maxY = try terrainFinite(grid.minimumY + Double(grid.rows) * grid.cellLength)
        guard footprint.minimumX >= grid.minimumX, footprint.maximumX <= maxX,
              footprint.minimumY >= grid.minimumY, footprint.maximumY <= maxY else { throw .outsideGrid }
        var cells: [TerrainSubareaHistory] = []
        cells.reserveCapacity(grid.undeformedHeights.count)
        var totalArea = 0.0
        for index in grid.undeformedHeights.indices {
            try terrainLoad { () throws(LoadError) in try work.charge(1) }
            let column = index % grid.columns, row = index / grid.columns
            let x0 = max(footprint.minimumX, grid.minimumX + Double(column) * grid.cellWidth)
            let x1 = min(footprint.maximumX, grid.minimumX + Double(column + 1) * grid.cellWidth)
            let y0 = max(footprint.minimumY, grid.minimumY + Double(row) * grid.cellLength)
            let y1 = min(footprint.maximumY, grid.minimumY + Double(row + 1) * grid.cellLength)
            if x1 <= x0 || y1 <= y0 { continue }
            let area = try terrainFinite((x1 - x0) * (y1 - y0))
            guard area > 0 else { throw .nonFiniteResult }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Arbitrary preloaded/precompacted initial soil
            // cannot be fabricated by initialHistory. Its public virgin path rejects load;
            // nonvirgin success requires an issued checkpoint or a calibrated state importer.
            guard interfaceHeight >= grid.undeformedHeights[index] else { throw .initiallyLoadedState }
            totalArea = try terrainFinite(totalArea + area)
            cells.append(TerrainSubareaHistory(cellIndex: index, area: area,
                centroidX: x0 + (x1 - x0) / 2, centroidY: y0 + (y1 - y0) / 2,
                currentSinkage: 0, peakSinkage: 0, irreversibleSinkage: 0, shearTravel: 0,
                recoverableEnergy: 0, cumulativeCompactionLoss: 0, cumulativeShearLoss: 0))
        }
        let areaTolerance = try terrainFinite(policy.absoluteAreaTolerance + policy.relativeTolerance * footprint.area)
        guard !cells.isEmpty, abs(totalArea - footprint.area) <= areaTolerance else { throw .physicalAcceptanceFailed }
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        return TerrainPatchHistory(grid: grid, calibration: calibration, footprint: footprint,
            interfaceBody: interfaceBody, interfaceHeight: interfaceHeight, timeSeconds: timeSeconds, sequence: 0, cells: cells)
    }

    public func evaluate(step: TerrainContactStep, accepted: TerrainPatchHistory,
                         policy: TerrainAcceptancePolicy, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchTrial {
        let grid = accepted.grid, calibration = accepted.calibration
        try terrainReserve(base: 384, perCell: 40, cells: grid.undeformedHeights.count, work: &work)
        try TerrainSourceAccounting.history(accepted, work: &work)
        try TerrainSourceAccounting.step(step, work: &work)
        guard step.interfaceBody == accepted.interfaceBody, step.terrainBody == grid.terrainBody,
              step.referenceFrame == grid.referenceFrame, step.gridRevision == grid.revision,
              step.calibrationRevision == calibration.revision else { throw .staleSource }
        guard step.startTimeSeconds == accepted.timeSeconds else { throw .staleTime }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Moving/rotating footprints need a conservative
        // subcell history remapping owner. The public evaluate path rejects changed bounds;
        // success requires independent area/history/energy transfer and moving-contact proof.
        guard step.footprint == accepted.footprint else { throw .changingFootprint }
        let domain = calibration.domain
        guard step.timeStepSeconds >= domain.minimumTimeStep,
              step.timeStepSeconds <= domain.maximumTimeStep else { throw .outsideCalibratedDomain }
        let (sequence, overflow) = accepted.sequence.addingReportingOverflow(1)
        guard !overflow else { throw .sequenceOverflow }
        let time = try terrainFinite(accepted.timeSeconds + step.timeStepSeconds)
        guard time > accepted.timeSeconds else { throw .staleTime }
        let relative = try terrainCore { () throws(CoreError) in try step.interfaceVelocity.subtracting(step.terrainVelocity) }
        let velocity = try terrainCore { () throws(CoreError) in try grid.terrainToReference.conjugated().rotating(relative) }
        let tangentialSpeed = try terrainFinite(ScalarMath.norm(velocity.x, velocity.y))
        guard tangentialSpeed <= domain.maximumTangentialSpeed,
              abs(velocity.z) <= domain.maximumNormalSpeed else { throw .outsideCalibratedDomain }
        let heightIncrement = try terrainFinite(velocity.z * step.timeStepSeconds)
        guard velocity.z == 0 || heightIncrement != 0 else { throw .nonFiniteResult }
        let newHeight = try terrainFinite(accepted.interfaceHeight + heightIncrement)
        guard heightIncrement == 0 || newHeight != accepted.interfaceHeight else { throw .nonFiniteResult }
        let coefficient = try terrainFinite(calibration.cohesiveModulus / accepted.footprint.width + calibration.frictionalModulus)
        guard coefficient > 0 else { throw .nonFiniteResult }
        var nextCells: [TerrainSubareaHistory] = [], responses: [TerrainCellResponse] = []
        nextCells.reserveCapacity(accepted.cells.count); responses.reserveCapacity(accepted.cells.count)
        var force = Vector3.zero, moment = Vector3.zero
        var deltaEnergy = 0.0, compaction = 0.0, shear = 0.0, localWork = 0.0, normalLoad = 0.0
        var strengthExcess = -Double.greatestFiniteMagnitude
        for old in accepted.cells {
            let cell = try TerrainCellKernel.evaluate(old: old, grid: grid, calibration: calibration,
                coefficient: coefficient, oldHeight: accepted.interfaceHeight,
                newHeight: newHeight, heightIncrement: heightIncrement,
                localVelocity: velocity, timeStep: step.timeStepSeconds, policy: policy, work: &work)
            nextCells.append(cell.0); responses.append(cell.1)
            force = try terrainCore { () throws(CoreError) in try force.adding(cell.1.forceOnInterface) }
            moment = try terrainCore { () throws(CoreError) in
                try moment.adding(cell.1.point.subtracting(step.wrenchReferencePoint).cross(cell.1.forceOnInterface))
            }
            deltaEnergy = try terrainFinite(deltaEnergy + cell.1.recoverableEnergyChange)
            compaction = try terrainFinite(compaction + cell.1.compactionLoss)
            shear = try terrainFinite(shear + cell.1.shearLoss)
            localWork = try terrainFinite(localWork - cell.1.meanNormalPressure * old.area * -heightIncrement - cell.1.shearLoss)
            normalLoad = try terrainFinite(normalLoad + cell.1.meanNormalPressure * old.area)
            strengthExcess = max(strengthExcess, cell.2)
        }
        guard normalLoad <= domain.maximumNormalLoad else { throw .outsideCalibratedDomain }
        let interfaceWrench = SpatialWrench(torque: moment, force: force)
        let terrainWrench = try terrainCore { () throws(CoreError) in
            SpatialWrench(torque: try moment.scaled(by: -1), force: try force.scaled(by: -1))
        }
        let interfaceWork = try terrainCore { () throws(CoreError) in
            try (interfaceWrench.power(against: SpatialMotion(angular: .zero, linear: step.interfaceVelocity)) +
                 terrainWrench.power(against: SpatialMotion(angular: .zero, linear: step.terrainVelocity))) * step.timeStepSeconds
        }
        let energyResidual = try terrainFinite(interfaceWork + deltaEnergy + compaction + shear)
        let workResidual = try terrainFinite(interfaceWork - localWork)
        let energyScale = max(policy.referenceEnergy, max(abs(interfaceWork), max(abs(localWork),
                          max(abs(deltaEnergy), max(abs(compaction), abs(shear))))))
        let tolerance = try terrainFinite(policy.absoluteEnergyTolerance + policy.relativeTolerance * energyScale)
        guard compaction >= -tolerance, shear >= -tolerance, abs(energyResidual) <= tolerance,
              abs(workResidual) <= tolerance else { throw .physicalAcceptanceFailed }
        let candidate = TerrainPatchHistory(grid: grid, calibration: calibration, footprint: accepted.footprint,
            interfaceBody: accepted.interfaceBody, interfaceHeight: newHeight, timeSeconds: time, sequence: sequence, cells: nextCells)
        let response = TerrainPatchResponse(step: step, cells: responses, interfaceWrench: interfaceWrench,
            terrainWrench: terrainWrench, meanNormalLoad: normalLoad, interfaceWork: interfaceWork,
            recoverableEnergyChange: deltaEnergy, compactionLoss: compaction, shearLoss: shear,
            originalEnergyResidual: energyResidual, originalLocalWorldWorkResidual: workResidual, originalStrengthExcess: strengthExcess)
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        return TerrainPatchTrial(response: response, base: accepted, candidate: candidate)
    }

    public func accept(trial: TerrainPatchTrial, replacing accepted: TerrainPatchHistory,
                       work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory {
        try terrainReserve(base: 256, perCell: 0, cells: 0, work: &work)
        try TerrainSourceAccounting.history(accepted, work: &work)
        try TerrainSourceAccounting.history(trial.base, work: &work)
        guard accepted == trial.base else { throw .staleSource }
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        return trial.candidate
    }

    public func checkpoint(accepted: TerrainPatchHistory, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchCheckpoint {
        try terrainReserve(base: 256, perCell: 0, cells: 0, work: &work)
        try TerrainSourceAccounting.history(accepted, work: &work)
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        return TerrainPatchCheckpoint(accepted: accepted)
    }

    public func restore(checkpoint: TerrainPatchCheckpoint, currentGrid: TerrainGrid,
                        currentCalibration: TerrainSoilCalibration, currentFootprint: TerrainRectangularFootprint,
                        currentInterfaceBody: ModelReference, work: inout LoadWork) throws(TerrainLawError) -> TerrainPatchHistory {
        try terrainReserve(base: 256, perCell: 0, cells: 0, work: &work)
        try TerrainSourceAccounting.history(checkpoint.accepted, work: &work)
        try TerrainSourceAccounting.grid(currentGrid, work: &work)
        try TerrainSourceAccounting.calibration(currentCalibration, work: &work)
        try terrainCharge(currentInterfaceBody.id.key, work: &work)
        guard currentGrid == checkpoint.accepted.grid, currentCalibration == checkpoint.accepted.calibration,
              currentFootprint == checkpoint.accepted.footprint,
              currentInterfaceBody == checkpoint.accepted.interfaceBody else { throw .staleSource }
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        return checkpoint.accepted
    }
}
