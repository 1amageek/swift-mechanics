public struct InertialParameterInput: Sendable {
    public let primal: MechanicalDerivativeInput
    public let bindings: [RigidInertialParameterBinding]
    /// Current source records in the exact tree body order, supplied by their model/CAD owner.
    public let currentRepresentations: [InertialRepresentation3D]
    public let mappingPreservesTopology: Bool
    /// Explicit law assumption for supplied force values held fixed under this inertial direction.
    public let loadsAreParameterIndependent: Bool

    public init(primal: MechanicalDerivativeInput, bindings: [RigidInertialParameterBinding],
                currentRepresentations: [InertialRepresentation3D], mappingPreservesTopology: Bool,
                loadsAreParameterIndependent: Bool) {
        self.primal = primal; self.bindings = bindings; self.currentRepresentations = currentRepresentations
        self.mappingPreservesTopology = mappingPreservesTopology
        self.loadsAreParameterIndependent = loadsAreParameterIndependent
    }
}
