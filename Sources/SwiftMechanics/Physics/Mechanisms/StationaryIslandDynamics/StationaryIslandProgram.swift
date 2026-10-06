public final class StationaryIslandProgram: Sendable {
    public let source: CompiledMechanicalModel
    public let constraints: QuadraticConstraintSystem
    public let drive: [Double]
    public let policy: StationaryIslandPolicy
    public let islands: [StationaryMechanicalIsland]
    public let binding: [UInt8]
    internal let inertias: [RigidBodyInertia]
    internal init(source: CompiledMechanicalModel, constraints: QuadraticConstraintSystem, drive: [Double],
                  policy: StationaryIslandPolicy, islands: [StationaryMechanicalIsland], binding: [UInt8],
                  inertias: [RigidBodyInertia]) {
        self.source=source; self.constraints=constraints; self.drive=drive; self.policy=policy
        self.islands=islands; self.binding=binding; self.inertias=inertias
    }
}
