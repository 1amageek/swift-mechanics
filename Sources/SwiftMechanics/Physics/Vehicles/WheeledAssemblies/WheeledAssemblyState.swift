public struct WheeledAssemblyState: Sendable {
    public let kinematic: CompiledKinematicState
    public let steering: ActuatorState
    public let sequence: UInt64
    public let cumulativeAbsoluteEnergyDefect: Double
    internal let configuration: WheeledAssemblyConfiguration
    internal let jointPositions, jointVelocities: [Int]
    internal let inertias: [RigidBodyInertia]
    internal init(configuration: WheeledAssemblyConfiguration, kinematic: CompiledKinematicState, steering: ActuatorState,
                  sequence: UInt64, cumulativeAbsoluteEnergyDefect: Double, jointPositions: [Int], jointVelocities: [Int], inertias: [RigidBodyInertia]) {
        self.configuration=configuration; self.kinematic=kinematic; self.steering=steering
        self.sequence=sequence; self.cumulativeAbsoluteEnergyDefect=cumulativeAbsoluteEnergyDefect
        self.jointPositions=jointPositions; self.jointVelocities=jointVelocities; self.inertias=inertias
    }
}
