public enum FieldOutputsQualificationCase: CaseIterable, Sendable {
    case affineShearAndSampling
    case volumetricAndAssembly
    case rotationWithinDomain
    case averagingAndMaterials
    case sourceAndLocationRefusals
    case resourcesAndCancellation

    public var label: String {
        switch self {
        case .affineShearAndSampling: "affine shear and sampling"
        case .volumetricAndAssembly: "volumetric and assembly"
        case .rotationWithinDomain: "rotation within declared domain"
        case .averagingAndMaterials: "averaging and material discontinuity"
        case .sourceAndLocationRefusals: "source and location refusals"
        case .resourcesAndCancellation: "resources and cancellation"
        }
    }
}
