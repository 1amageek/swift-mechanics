internal enum GeometricMechanismChart {
    static func signature(_ geometry:GeometricConstraintSystem,projection:ManifoldProjectionPolicy,policy:MechanismSolvePolicy,
                          drive:[Double],dimensions:[PhysicalDimension],inertias:NonlinearPhysicalInertias,chartLimit:Double,
                          publication:NumericalBudget,maximum:Int) throws(RuntimeFailure) -> String {
        let bound:Int
        do { bound=try NumericalWork.sum(geometry.metadata.utf8.count,try NumericalWork.sum(projection.metadata.utf8.count,
            try NumericalWork.product(17,try NumericalWork.sum(48,try NumericalWork.sum(try NumericalWork.product(8,dimensions.count),try NumericalWork.sum(try NumericalWork.product(4,drive.count),try NumericalWork.product(13,inertias.count))))))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Geometric descriptor capacity overflow.") }
        guard bound <= maximum else { throw RuntimeFailure(.capacityExceeded,message:"Geometric descriptor capacity exhausted.") }
        var result=inertias.isPlanar ? "geometric-planar-projected-v2:" : "geometric-projected-v1:";result.reserveCapacity(bound)
        result.append(geometry.metadata);result.append(":");result.append(projection.metadata)
        func put(_ value:UInt64) { result.append(":");result.append(String(value,radix:16)) }
        let joint=geometry.model.policy.jointPolicy
        put(joint.quaternionTolerance.absolute.bitPattern);put(joint.quaternionTolerance.relative.bitPattern)
        put(joint.chartRankRelative.bitPattern);put(joint.characteristicLengthMeters.bitPattern)
        put(chartLimit.bitPattern);put(policy.originalTolerance.bitPattern);put(policy.dynamics.energyScale.bitPattern)
        put(policy.dynamics.timeScale.bitPattern);put(policy.constraints.originalResidualTolerance.bitPattern)
        put(policy.constraints.maximumCorrection.bitPattern);put(policy.constraints.rankRelativeTolerance.bitPattern);put(UInt64(policy.constraints.rankPolicy == .allowRedundancy ? 0 : 1))
        for capability in [policy.dynamics.capability,policy.constraints.linearCapability] {
            put(UInt64(capability.precision == .float64 ? 0 : 1));put(UInt64(capability.backend == .referenceCPU ? 0 : 1))
            switch capability.algorithm { case .cholesky:put(0);case .partialPivotLU:put(1);case .conjugateGradient:put(2);case .treeElimination:put(3) }
        }
        for tolerance in [policy.dynamics.linearTolerance,policy.constraints.linearTolerance] {
            put(tolerance.absoluteResidual.bitPattern);put(tolerance.relativeResidual.bitPattern);put(tolerance.pivotThreshold.bitPattern)
        }
        put(UInt64(publication.scalarStorage));put(UInt64(publication.arithmeticOperations));put(UInt64(publication.iterations))
        for dimension in dimensions {
            for value in [dimension.length,dimension.mass,dimension.time,dimension.angle,dimension.electricCurrent,dimension.temperature,dimension.amount,dimension.luminousIntensity] { put(UInt64(bitPattern:Int64(value))) }
        }
        for i in drive.indices { put(drive[i].bitPattern);put(policy.constraints.diagonalMetric[i].bitPattern) }
        switch inertias {
        case .spatial(let values):
            for inertia in values {
                let p=inertia.properties,m=p.inertiaAtCenter
                for value in [p.mass,p.centerOfMass.x,p.centerOfMass.y,p.centerOfMass.z,m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22] { put(value.bitPattern) }
            }
        case .planar(let values):
            put(2)
            for inertia in values {
                let p=inertia.properties
                for value in [p.mass,p.centerX,p.centerY,p.polarInertiaAtCenter] { put(value.bitPattern) }
            }
        }
        return result
    }
}
