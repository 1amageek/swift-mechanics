public struct TaskSpaceRequest: Sendable {
    public enum Command: Sendable {
        case pointMotion(TaskSpaceMotion)
        case bodyOriginWrench(TaskSpaceWrench)
        case hybrid(motion: TaskSpaceMotion, wrench: TaskSpaceWrench)
        case constrainedContactForce(TaskSpaceWrench)
    }
    public let system: PhysicalRigidDynamicsSystem
    public let expectedRevision: UInt64
    public let expectedTime: Double
    public let worldFrame: EntityID
    public let command: Command
    public init(system: PhysicalRigidDynamicsSystem, expectedRevision: UInt64, expectedTime: Double,
                worldFrame: EntityID, command: Command) {
        self.system = system; self.expectedRevision = expectedRevision; self.expectedTime = expectedTime
        self.worldFrame = worldFrame; self.command = command
    }
}
