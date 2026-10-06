/// Signed tangent coefficients; mass may be zero or negative and is not a physical body mass.
public struct RigidInertialParameterDirection: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let modelRevision: UInt64
    public let source: SourceProvenance
    public let parameterIDs: [UInt64]
    public let mass: Double
    public let firstMoment: Vector3
    public let inertiaAtOrigin: Matrix3

    public init(binding: RigidInertialParameterBinding, mass: Double = 0, firstMoment: Vector3 = .zero,
                inertiaAtOrigin: Matrix3 = .zero) throws(InertialParameterError) {
        guard mass.isFinite, inertiaAtOrigin.m01 == inertiaAtOrigin.m10,
              inertiaAtOrigin.m02 == inertiaAtOrigin.m20, inertiaAtOrigin.m12 == inertiaAtOrigin.m21 else { throw .invalidInput }
        self.body = binding.body; self.frame = binding.frame; self.modelRevision = binding.modelRevision
        self.source = binding.representation.provenance; self.parameterIDs = binding.parameterIDs
        self.mass = mass; self.firstMoment = firstMoment; self.inertiaAtOrigin = inertiaAtOrigin
    }
}
