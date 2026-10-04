
public protocol ConstraintAssembling: Sendable {
    func assemble(_ system: QuadraticConstraintSystem, initialPosition: [Double], time: Double,
                  policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintAssemblySolution
    func projectVelocity(_ sample: VelocityConstraintSample, initialVelocity: [Double], policy: ConstraintSolvePolicy,
                         work: inout NumericalWork, linearWork: inout NumericalWork) throws(ConstraintError) -> ConstraintVelocitySolution
}
