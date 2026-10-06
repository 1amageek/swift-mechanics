public struct JointStopInput: Sendable {
    public let model: CompiledMechanicalModel
    public let state: CompiledKinematicState
    public let inertias: [RigidBodyInertia]
    public let definition: JointStopDefinition
    public let expectedTimeSeconds: Double
    public init(model: CompiledMechanicalModel, state: CompiledKinematicState, inertias: [RigidBodyInertia],
                definition: JointStopDefinition, expectedTimeSeconds: Double) {
        self.model=model; self.state=state; self.inertias=inertias; self.definition=definition
        self.expectedTimeSeconds=expectedTimeSeconds
    }
}
