/// Symmetric two-bar model with a vertically guided apex; horizontal modes are excluded by the boundary condition.
public struct NonlinearTruss: Sendable {
    public let identity: String
    public let revision: UInt64
    public let frame: EntityID
    public let source: SourceProvenance
    public let halfSpan: Double
    public let initialHeight: Double
    public let axialRigidity: Double
    public let maximumAbsoluteEngineeringStrain: Double
    public init(identity: String,revision: UInt64,frame: EntityID,source: SourceProvenance,halfSpan: Double,initialHeight: Double,
                axialRigidity: Double,maximumAbsoluteEngineeringStrain: Double) throws(StructuralError) {
        guard !identity.isEmpty,frame.kind == .frame,halfSpan.isFinite,halfSpan>0,initialHeight.isFinite,initialHeight>0,
              axialRigidity.isFinite,axialRigidity>0,maximumAbsoluteEngineeringStrain.isFinite,
              maximumAbsoluteEngineeringStrain>0,maximumAbsoluteEngineeringStrain<1 else { throw .invalidInput }
        self.identity=identity;self.revision=revision;self.frame=frame;self.source=source;self.halfSpan=halfSpan;self.initialHeight=initialHeight
        self.axialRigidity=axialRigidity;self.maximumAbsoluteEngineeringStrain=maximumAbsoluteEngineeringStrain
    }
}
