
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol SmoothODEEquations: Sendable {
    var descriptor: ODEDescriptor { get }
    func validate(model: CompiledMechanicalModel) throws(RuntimeFailure)
    func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure)
    func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure)
    func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure)
    func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure)
    func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure)
}
