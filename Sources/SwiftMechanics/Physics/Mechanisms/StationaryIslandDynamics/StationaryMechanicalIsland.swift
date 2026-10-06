public final class StationaryMechanicalIsland: Sendable {
    public let id: UInt64
    public let model: CompiledMechanicalModel
    public let sourceCoordinateIndices: [Int]
    public let coordinateIDs: [UInt64]
    public let retainedRowIDs: [UInt64]
    public let constraints: QuadraticConstraintSystem?
    public let drive: [Double]
    public let policy: MechanismSolvePolicy
    internal let inertias: [RigidBodyInertia]
    internal init(id: UInt64, model: CompiledMechanicalModel, indices: [Int], layout: ConstraintCoordinateLayout,
                  constraints: QuadraticConstraintSystem?, drive: [Double], policy: MechanismSolvePolicy,
                  inertias: [RigidBodyInertia]) {
        self.id=id; self.model=model; sourceCoordinateIndices=indices; coordinateIDs=layout.coordinateIDs
        retainedRowIDs=constraints?.rows.map { $0.id } ?? []; self.constraints=constraints
        self.drive=drive; self.policy=policy; self.inertias=inertias
    }
}
