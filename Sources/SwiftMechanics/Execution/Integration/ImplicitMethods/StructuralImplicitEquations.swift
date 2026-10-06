public protocol StructuralImplicitEquations: Sendable {
    var descriptor: ODEDescriptor { get }
    var residualDimensions: [PhysicalDimension] { get }
    var implicitDomain: ImplicitEquationDomain { get }
    var massDomain: StructuralMassDomain { get }
    /// The physical balance is M*a + C(q,v,t) - load(q,v,t), with constant M.
    func residual(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                  into output: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause)
    /// Recomputes the original physical balance independently of any solver residual cache.
    func originalResidual(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                          into output: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause)
    /// Writes cq*R_q + cv*R_v + ca*R_a, row-major, at the supplied physical state.
    func tangent(time: Double, displacement: [Double], velocity: [Double], acceleration: [Double],
                 displacementCoefficient: Double, velocityCoefficient: Double, accelerationCoefficient: Double,
                 into rowMajorOutput: inout [Double], work: inout NumericalWork) throws(ImplicitMethodCause)
}
