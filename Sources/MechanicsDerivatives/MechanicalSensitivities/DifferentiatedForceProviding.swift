import MechanicsJoints
import MechanicsNumerics
public protocol DifferentiatedForceProviding: Sendable {
    var metadata: ForceDerivativeMetadata { get }
    func value(_ snapshot: KinematicSnapshot, state: KinematicState, parameters: [Double], into output: inout [Double],
               work: inout NumericalWork) throws(DerivativeError)
    func direction(_ tangent: TreeTangent, state: KinematicState, treeDirection: TreeDirection, parameters: [Double], parameterDirection: [Double],
                   into output: inout [Double], work: inout NumericalWork) throws(DerivativeError)
}
