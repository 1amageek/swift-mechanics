public enum MachineEntityReference: Equatable, Sendable {
    case local(EntityID)
    case absolute(EntityID)
}
