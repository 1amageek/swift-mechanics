public enum ModalReductionQualificationCase: CaseIterable, Sendable {
    case constitutiveReconstruction, locationAndSource, originalForceEnergyPower
    case finiteDomainAndLegacy, workAndCallLimits, cooperativeCancellation
    public var label: String {
        switch self {
        case .constitutiveReconstruction: "actual current constitutive reconstruction"
        case .locationAndSource: "original material location and source"
        case .originalForceEnergyPower: "original force energy and power"
        case .finiteDomainAndLegacy: "finite domain and legacy refusal"
        case .workAndCallLimits: "original numerical and call limits"
        case .cooperativeCancellation: "cooperative early and late cancellation"
        }
    }
}
