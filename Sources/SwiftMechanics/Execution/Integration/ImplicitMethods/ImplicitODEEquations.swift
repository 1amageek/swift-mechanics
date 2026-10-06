@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol ImplicitODEEquations: SmoothODEEquations {
    var implicitDomain: ImplicitEquationDomain { get }
    /// Writes the exact row-major derivative df_i/dy_j of the declared chart equation.
    func derivativeJacobian(time: Double, point: [Double], into rowMajorOutput: inout [Double],
                            work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure)
}
