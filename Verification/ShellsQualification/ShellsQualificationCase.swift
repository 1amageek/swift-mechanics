public enum ShellsQualificationCase: CaseIterable, Sendable {
    case membranePatch, bendingAndShear, massAndDamping
    case rigidFrameAndPower, originalRefusals, resourcesAndCancellation
    public var label: String {
        switch self {
        case .membranePatch: return "plane stress membrane patch"
        case .bendingAndShear: return "constant curvature and tied shear"
        case .massAndDamping: return "physical mass and damping"
        case .rigidFrameAndPower: return "rigid modes frame and virtual power"
        case .originalRefusals: return "original typed refusals"
        case .resourcesAndCancellation: return "resources and cancellation"
        }
    }
}
