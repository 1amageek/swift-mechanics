/// Recomputes sealed original authority for an upper consumer receiving an opaque witness supplier.
public enum GeometricPhysicalRowAcceptance {
    public static func validated(_ supplied: GeometricPhysicalRowWitness, system: GeometricConstraintSystem, state: KinematicState,
                                 policy: GeometricPhysicalRowPolicy, work: inout NumericalWork) throws(GeometricConstraintError) -> GeometricPhysicalRowWitness {
        let original = try GeometricPhysicalRowWitness.make(system,state:state,supplied:supplied.original,policy:policy,work:&work)
        guard supplied.model == original.model, supplied.dimension == original.dimension, supplied.fidelity == original.fidelity,
              supplied.metadata == original.metadata, supplied.rows == original.rows,
              supplied.convention == original.convention else { throw .staleSource }
        return original
    }
}
