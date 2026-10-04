/// Sealed builtin verification from original immutable records; supplied diagnostics are never authority.
public enum GeometricOriginalAcceptance {
    @inline(never)
    public static func validate(_ supplied:HolonomicGeometrySample,system:GeometricConstraintSystem,state:KinematicState,
                                tolerance:Double,policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(GeometricConstraintError) {
        _=try validatedSample(supplied,system:system,state:state,tolerance:tolerance,policy:policy,work:&work)
    }
    /// Returns recomputed original values, preventing a within-tolerance diagnostic from relaxing final feasibility.
    @inline(never)
    public static func validatedSample(_ supplied:HolonomicGeometrySample,system:GeometricConstraintSystem,state:KinematicState,
                                       tolerance:Double,policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        guard tolerance.isFinite,tolerance >= 0 else { throw .invalidInput }
        let original=try GeometricRelationEvaluator.compute(system,state:state,policy:policy,original:true,work:&work)
        let a=supplied.velocity,b=original.velocity,n=state.v.count
        let comparisonWork=try GeometricArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.sum(system.metadata.utf8.count,try NumericalWork.sum(try NumericalWork.product(512,try NumericalWork.product(system.model.tree.bodies.count,n+1)),
                try NumericalWork.product(8,try NumericalWork.product(system.rowIDs.count,n+3))))
        }
        try GeometricArithmetic.charge(comparisonWork,&work)
        guard supplied.source == state,supplied.metadata == system.metadata,sourceMatches(supplied.snapshot,original.snapshot),
              a.layout.revision == b.layout.revision,a.layout.coordinateIDs == b.layout.coordinateIDs,a.layout.dimensions == b.layout.dimensions,
              a.layout.scales == b.layout.scales,a.layout.timeScale == b.layout.timeScale,a.isIntegrable,
              supplied.alignmentResiduals.count == original.alignmentResiduals.count,a.rowIDs == b.rowIDs,supplied.values.count == b.rowIDs.count,a.rows.count == b.rows.count,
              a.drift.count == b.drift.count,a.accelerationBias.count == b.accelerationBias.count else { throw .staleSource }
        for row in b.rowIDs.indices {
            guard close(supplied.values[row],original.values[row],tolerance),close(a.drift[row],b.drift[row],tolerance),
                  close(a.accelerationBias[row],b.accelerationBias[row],tolerance) else { throw .originalRejected(row:b.rowIDs[row]) }
            for j in 0..<n { guard close(a.rows[row*n+j],b.rows[row*n+j],tolerance) else { throw .originalRejected(row:b.rowIDs[row]) } }
        }
        for i in original.alignmentResiduals.indices {
            let lhs=supplied.alignmentResiduals[i],rhs=original.alignmentResiduals[i]
            guard close(lhs.x,rhs.x,tolerance),close(lhs.y,rhs.y,tolerance),close(lhs.z,rhs.z,tolerance) else { throw .invalidGeometry }
        }
        try GeometricArithmetic.check(policy);return original
    }
    private static func close(_ a:Double,_ b:Double,_ tolerance:Double) -> Bool { a.isFinite && b.isFinite && abs(a-b) <= tolerance*(1+abs(b)) }
    private static func sourceMatches(_ a:KinematicSnapshot,_ b:KinematicSnapshot) -> Bool {
        guard a.time == b.time,a.tree.revision == b.tree.revision,a.tree.layout == b.tree.layout,a.tree.bodies == b.tree.bodies,
              a.tree.joints == b.tree.joints,a.tree.rootBase == b.tree.rootBase,a.tree.worldFrame == b.tree.worldFrame,
              a.tree.frameCount == b.tree.frameCount,a.bodies == b.bodies,a.frames == b.frames,a.joints == b.joints,a.coordinateRate == b.coordinateRate else { return false }
        for body in b.tree.bodies {
            do throws(JointError) { guard try a.geometricColumns(body:body.id).elementsEqual(b.geometricColumns(body:body.id)) else { return false } } catch { return false }
        }
        return true
    }
}
