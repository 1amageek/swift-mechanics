public protocol StationaryIslandPreparing: Sendable {
    func prepare(source: CompiledMechanicalModel, constraints: QuadraticConstraintSystem, drive: [Double],
                 policy: StationaryIslandPolicy, work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandProgram
}
