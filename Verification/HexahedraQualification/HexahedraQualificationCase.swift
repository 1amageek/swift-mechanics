public enum HexahedraQualificationCase: CaseIterable, Sendable {
    case affinePatchAndTangent
    case nonAffineEnergyGradient
    case finiteObjectivityAndRigidModes
    case massAndMaterialAssignments
    case geometryAndBindingRefusals
    case resourcesAndCancellation

    public var label: String {
        switch self {
        case .affinePatchAndTangent: "affine patch and tangent"
        case .nonAffineEnergyGradient: "non-affine discrete energy gradient"
        case .finiteObjectivityAndRigidModes: "finite objectivity and rigid modes"
        case .massAndMaterialAssignments: "mass and material assignments"
        case .geometryAndBindingRefusals: "geometry and binding refusals"
        case .resourcesAndCancellation: "resources and cancellation"
        }
    }
}
