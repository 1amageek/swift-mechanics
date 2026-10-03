public enum RuntimeContributorCategory: UInt8, Equatable, Sendable {
    case actuator = 0, controller = 1, event = 2, random = 3, warmStart = 4, integrator = 5, constitutive = 6, backend = 7, observation = 8
}
