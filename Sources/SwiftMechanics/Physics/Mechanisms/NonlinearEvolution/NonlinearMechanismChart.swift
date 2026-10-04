internal enum NonlinearMechanismChart {
    static func signature(_ system:QuadraticConstraintSystem, velocity:ConstraintCoordinateLayout, drive:[Double],
                          policy:MechanismSolvePolicy, projection:NonlinearMechanismProjectionPolicy, maximum:Int) throws(MechanismError) -> String {
        let p=system.layout.scales.count,m=system.rows.count,n=velocity.scales.count
        let fields:Int
        do { fields=try NumericalWork.sum(16,try NumericalWork.sum(try NumericalWork.product(6,p),try NumericalWork.sum(try NumericalWork.product(5,n),try NumericalWork.product(m,try NumericalWork.sum(5,try NumericalWork.sum(try NumericalWork.product(2,p),try NumericalWork.product(p,p))))))) }
        catch { throw .capacityExceeded }
        let bound:Int
        do { bound=try NumericalWork.sum(32,try NumericalWork.product(17,fields)) } catch { throw .capacityExceeded }
        guard maximum >= bound else { throw .capacityExceeded }
        var result="nonlinear-projected-manifold-v1"
        func put(_ value:UInt64) { result.append(":");result.append(String(value,radix:16)) }
        put(system.layout.revision);put(system.layout.timeScale.bitPattern);put(velocity.timeScale.bitPattern)
        put(policy.dynamics.energyScale.bitPattern);put(projection.position.energyScale.bitPattern);put(system.minimumTime.bitPattern);put(system.maximumTime.bitPattern);put(policy.originalTolerance.bitPattern)
        put(projection.position.originalResidualTolerance.bitPattern);put(projection.maximumCorrection.bitPattern)
        put(UInt64(projection.maximumIterations));put(UInt64(projection.position.rankPolicy == .allowRedundancy ? 1 : 0))
        put(projection.position.rankRelativeTolerance.bitPattern);put(policy.constraints.rankRelativeTolerance.bitPattern)
        for i in 0..<p { put(system.layout.coordinateIDs[i]);put(system.layout.scales[i].bitPattern);put(system.minimumPosition[i].bitPattern);put(system.maximumPosition[i].bitPattern);put(projection.position.diagonalMetric[i].bitPattern) }
        for i in 0..<n { put(velocity.coordinateIDs[i]);put(velocity.scales[i].bitPattern);put(drive[i].bitPattern);put(policy.constraints.diagonalMetric[i].bitPattern) }
        for row in system.rows {
            put(row.id);put(row.constant.bitPattern);put(row.timeLinear.bitPattern);put(row.timeQuadratic.bitPattern)
            for values in [row.linear,row.mixedTime,row.hessian] { for value in values { put(value.bitPattern) } }
        }
        return result
    }
}
