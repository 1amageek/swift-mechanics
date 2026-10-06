public enum SpatialBeamsQualificationCase: CaseIterable, Sendable {
    case axialAndTorsion, bendingAndShear, massAndDamping
    case frameFieldsAndPower, originalRefusals, resourcesAndCancellation
    public var label: String {
        switch self {
        case .axialAndTorsion: return "axial and torsional operators"
        case .bendingAndShear: return "biaxial bending and shear compliance"
        case .massAndDamping: return "physical mass and damping"
        case .frameFieldsAndPower: return "frame fields and virtual power"
        case .originalRefusals: return "original typed refusals"
        case .resourcesAndCancellation: return "resources and cancellation"
        }
    }
}
