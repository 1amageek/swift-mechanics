public enum GeometricPhysicalAllocationAcceptance {
    /// Recomputes original authority after an opaque supplier boundary; array shapes and supplied rank are not authority.
    @inline(never)
    public static func validated(_ supplied:GeometricPhysicalAllocationWitness,system:GeometricConstraintSystem,state:KinematicState,
                                 policy:GeometricPhysicalAllocationPolicy,work:inout NumericalWork) throws(GeometricPhysicalAllocationError) -> GeometricPhysicalAllocationWitness {
        let original=try GeometricPhysicalAllocationWitness.make(system,state:state,supplied:supplied.rows,policy:policy,work:&work)
        do throws(NumericalError) { try work.chargeOperations(try NumericalWork.product(8,original.rows.rows.count)) }
        catch { throw .numerical(error) }
        let a=supplied.originalRank,b=original.originalRank
        guard a.rank == b.rank,a.independentRows == b.independentRows,a.dependentRowIDs == b.dependentRowIDs,
              a.reactionNullity == b.reactionNullity,supplied.activeRowIDs == original.activeRowIDs,
              supplied.zeroRowIDs == original.zeroRowIDs,supplied.physicalWrenchesUnique == original.physicalWrenchesUnique else { throw .staleSource }
        guard !Task.isCancelled,!policy.rows.evaluation.isCancelled(),!policy.rank.evaluation.isCancelled() else { throw .cancelled }
        return original
    }
}
