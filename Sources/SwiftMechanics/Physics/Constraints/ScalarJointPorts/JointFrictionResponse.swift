public enum JointFrictionResponse: Sendable {
    case disabled
    case sliding(effort: Double, dissipativePower: Double)
    case staticInterval(lowerEffort: Double, upperEffort: Double)
}
