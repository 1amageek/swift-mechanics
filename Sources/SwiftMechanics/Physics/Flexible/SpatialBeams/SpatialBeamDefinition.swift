public struct SpatialBeamDefinition: Equatable, Sendable {
    public let identity: String
    public let revision: UInt64
    public let source: SourceProvenance
    public let first: FlexibleNode
    public let second: FlexibleNode
    public let referenceFrame: EntityID
    public let elementFrame: EntityID
    public let principalYDirection: Vector3
    public let material: SpatialBeamMaterial
    public let section: SpatialBeamSection
    public let formulation: SpatialBeamFormulation
    public let massForm: SpatialBeamMassForm
    public let massDamping: Double
    public let stiffnessDamping: Double
    public let envelope: SpatialBeamEnvelope

    public init(identity: String, revision: UInt64, source: SourceProvenance,
                first: FlexibleNode, second: FlexibleNode, referenceFrame: EntityID,
                elementFrame: EntityID, principalYDirection: Vector3,
                material: SpatialBeamMaterial, section: SpatialBeamSection,
                formulation: SpatialBeamFormulation, massForm: SpatialBeamMassForm,
                massDamping: Double, stiffnessDamping: Double,
                envelope: SpatialBeamEnvelope) throws(SpatialBeamError) {
        guard !identity.isEmpty, first.identifier != second.identifier,
              referenceFrame.kind == .frame, elementFrame.kind == .frame,
              referenceFrame != elementFrame else { throw .invalidInput(parameter: "elementIdentity") }
        guard massDamping.isFinite, massDamping >= 0, stiffnessDamping.isFinite, stiffnessDamping >= 0 else {
            throw .invalidInput(parameter: "dampingCoefficients")
        }
        self.identity = identity; self.revision = revision; self.source = source
        self.first = first; self.second = second; self.referenceFrame = referenceFrame
        self.elementFrame = elementFrame; self.principalYDirection = principalYDirection
        self.material = material; self.section = section; self.formulation = formulation
        self.massForm = massForm; self.massDamping = massDamping; self.stiffnessDamping = stiffnessDamping
        self.envelope = envelope
    }
}
