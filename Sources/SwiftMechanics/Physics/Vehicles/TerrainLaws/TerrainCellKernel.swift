internal enum TerrainCellKernel {
    static func evaluate(old: TerrainSubareaHistory, grid: TerrainGrid, calibration: TerrainSoilCalibration,
                         coefficient: Double, oldHeight: Double, newHeight: Double, heightIncrement: Double,
                         localVelocity: Vector3, timeStep: Double, policy: TerrainAcceptancePolicy,
                         work: inout LoadWork) throws(TerrainLawError) -> (TerrainSubareaHistory, TerrainCellResponse, Double) {
        try terrainLoad { () throws(LoadError) in try work.charge(1) }
        let rawSinkage = try terrainFinite(grid.undeformedHeights[old.cellIndex] - newHeight)
        let sinkage = max(rawSinkage, 0)
        guard sinkage <= calibration.domain.maximumSinkage else { throw .outsideCalibratedDomain }
        let n = calibration.sinkageExponent, elastic = calibration.unloadingModulus
        let peak: Double, plastic: Double, endpointPressure: Double, compaction: Double
        if sinkage > old.peakSinkage {
            peak = sinkage
            endpointPressure = try terrainFinite(coefficient * TerrainScalarMath.power(peak, n))
            guard endpointPressure > 0 else { throw .nonFiniteResult }
            plastic = try terrainFinite(peak - endpointPressure / elastic)
            guard plastic >= old.irreversibleSinkage else { throw .physicalAcceptanceFailed }
            let peakIncrement = try terrainFinite(peak - old.peakSinkage)
            let pressureMean = try terrainFinite(coefficient * TerrainScalarMath.powerMean(
                start: old.peakSinkage, increment: peakIncrement, exponent: n))
            let plasticMean: Double
            if n == 1 {
                plasticMean = try terrainFinite(pressureMean * (1 - coefficient / elastic))
            } else {
                let elasticDerivativeMean = try terrainFinite((n * (coefficient / elastic)) * coefficient *
                    TerrainScalarMath.powerMean(start: old.peakSinkage, increment: peakIncrement,
                                                exponent: try terrainFinite(2 * n - 1)))
                plasticMean = try terrainFinite(pressureMean - elasticDerivativeMean)
            }
            compaction = try terrainFinite(old.area * (plasticMean * peakIncrement))
            guard compaction > 0 else { throw .nonFiniteResult }
        } else {
            peak = old.peakSinkage; plastic = old.irreversibleSinkage
            // Use the envelope value exactly at the shared branch junction. Recomputing
            // E*(peak-plastic) can change a pressure bit and create work at zero motion.
            if sinkage == peak {
                endpointPressure = try terrainFinite(coefficient * TerrainScalarMath.power(peak, n))
            } else {
                endpointPressure = max(try terrainFinite(elastic * (sinkage - plastic)), 0)
            }
            compaction = 0
        }
        guard endpointPressure <= calibration.domain.maximumPressure else { throw .outsideCalibratedDomain }
        let elasticSinkage = try terrainFinite(endpointPressure / elastic)
        guard endpointPressure == 0 || elasticSinkage > 0 else { throw .nonFiniteResult }
        let stored = try terrainFinite(old.area * (elasticSinkage * endpointPressure) / 2)
        guard endpointPressure == 0 || stored > 0 else { throw .nonFiniteResult }
        let energyChange = try terrainFinite(stored - old.recoverableEnergy)
        let normalWork = try terrainFinite(energyChange + compaction)
        let meanPressure: Double
        if heightIncrement == 0 {
            guard normalWork == 0 else { throw .physicalAcceptanceFailed }
            meanPressure = endpointPressure
        } else {
            let rawStart = try terrainFinite(grid.undeformedHeights[old.cellIndex] - oldHeight)
            meanPressure = try TerrainScalarMath.normalPressureMean(rawStart: rawStart, increment: -heightIncrement,
                peak: old.peakSinkage, plastic: old.irreversibleSinkage,
                coefficient: coefficient, exponent: n, elastic: elastic)
        }
        guard meanPressure >= 0, meanPressure <= calibration.domain.maximumPressure else { throw .physicalAcceptanceFailed }
        // Original requested displacement generates force work; rounded issued endpoint
        // state generates stored energy. Check their mismatch before adding shear energy.
        let integratedNormalWork = try terrainFinite(meanPressure * old.area * -heightIncrement)
        let normalResidual = try terrainFinite(integratedNormalWork - normalWork)
        let normalTolerance = try terrainFinite(policy.absoluteEnergyTolerance + policy.relativeTolerance *
            max(policy.referenceEnergy, max(abs(integratedNormalWork),
                max(abs(normalWork), max(abs(energyChange), abs(compaction))))))
        guard abs(normalResidual) <= normalTolerance else { throw .physicalAcceptanceFailed }
        let speed = try terrainFinite(ScalarMath.norm(localVelocity.x, localVelocity.y))
        let travelIncrement = meanPressure > 0 ? try terrainFinite(speed * timeStep) : 0
        guard speed == 0 || meanPressure == 0 || travelIncrement > 0 else { throw .nonFiniteResult }
        let travel = try terrainFinite(old.shearTravel + travelIncrement)
        guard travel <= calibration.domain.maximumShearTravel else { throw .outsideCalibratedDomain }
        guard travelIncrement == 0 || travel > old.shearTravel else { throw .nonFiniteResult }
        let strength = try terrainFinite(calibration.cohesion + calibration.frictionTangent * meanPressure)
        let tau: Double, fx: Double, fy: Double
        if travelIncrement == 0 { tau = 0; fx = 0; fy = 0 }
        else {
            let mean = try TerrainScalarMath.mobilization(oldTravel: old.shearTravel, increment: travelIncrement,
                                                         length: calibration.janosiLength, work: &work)
            tau = try terrainFinite(strength * mean)
            guard strength == 0 || tau > 0 else { throw .nonFiniteResult }
            let tangentialForce = try terrainFinite(tau * old.area)
            guard tau == 0 || tangentialForce > 0 else { throw .nonFiniteResult }
            fx = try terrainFinite(-tangentialForce * (localVelocity.x / speed))
            fy = try terrainFinite(-tangentialForce * (localVelocity.y / speed))
            guard tangentialForce == 0 || fx != 0 || fy != 0 else { throw .nonFiniteResult }
        }
        let shearLoss = try terrainFinite(tau * old.area * travelIncrement)
        guard tau == 0 || shearLoss > 0 else { throw .nonFiniteResult }
        let normalForce = try terrainFinite(meanPressure * old.area)
        guard meanPressure == 0 || normalForce > 0 else { throw .nonFiniteResult }
        let force = try terrainCore { () throws(CoreError) in
            try grid.terrainToReference.rotating(Vector3(fx, fy, normalForce))
        }
        let point = try terrainCore { () throws(CoreError) in
            try grid.referenceOrigin.adding(grid.terrainToReference.rotating(
                Vector3(old.centroidX, old.centroidY, newHeight)))
        }
        // Re-project the returned world force to inspect its original Mohr-Coulomb bound.
        let returnedLocal = try terrainCore { () throws(CoreError) in try grid.terrainToReference.conjugated().rotating(force) }
        let returnedPressure = try terrainFinite(returnedLocal.z / old.area)
        let returnedShear = try terrainFinite(ScalarMath.norm(returnedLocal.x, returnedLocal.y) / old.area)
        let excess = try terrainFinite(returnedShear - (calibration.cohesion + calibration.frictionTangent * returnedPressure))
        let energyTolerance = try terrainFinite(policy.absoluteEnergyTolerance + policy.relativeTolerance *
            max(policy.referenceEnergy, max(abs(normalWork), max(abs(energyChange), max(abs(compaction), abs(shearLoss))))))
        let pressureTolerance = try terrainFinite(policy.absolutePressureTolerance + policy.relativeTolerance *
            max(policy.referencePressure, max(meanPressure, strength)))
        guard compaction >= -energyTolerance, shearLoss >= -energyTolerance, stored >= 0,
              returnedPressure >= -pressureTolerance, excess <= pressureTolerance else { throw .physicalAcceptanceFailed }
        let cumulativeCompaction = try terrainFinite(old.cumulativeCompactionLoss + compaction)
        let cumulativeShear = try terrainFinite(old.cumulativeShearLoss + shearLoss)
        guard compaction == 0 || cumulativeCompaction > old.cumulativeCompactionLoss,
              shearLoss == 0 || cumulativeShear > old.cumulativeShearLoss else { throw .nonFiniteResult }
        let next = TerrainSubareaHistory(cellIndex: old.cellIndex, area: old.area,
            centroidX: old.centroidX, centroidY: old.centroidY, currentSinkage: sinkage,
            peakSinkage: peak, irreversibleSinkage: plastic, shearTravel: travel, recoverableEnergy: stored,
            cumulativeCompactionLoss: cumulativeCompaction, cumulativeShearLoss: cumulativeShear)
        let response = TerrainCellResponse(cellIndex: old.cellIndex, area: old.area, point: point,
            forceOnInterface: force, meanNormalPressure: meanPressure, endpointNormalPressure: endpointPressure,
            meanShearStress: tau, compactionLoss: compaction, shearLoss: shearLoss,
            recoverableEnergyChange: energyChange)
        return (next, response, excess)
    }
}
