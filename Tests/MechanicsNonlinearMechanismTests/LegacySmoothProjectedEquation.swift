import SwiftMechanics

/// A pre-boundary custom conformer deliberately retains the legacy method set.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct LegacySmoothProjectedEquation: ProjectedMechanismEquations {
    let original:NonlinearMechanismEquation
    var model:CompiledMechanicalModel { original.model }
    var descriptor:ODEDescriptor { original.descriptor }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) { try original.validate(model:model) }
    func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) { try original.read(state,into:&point) }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) { try original.read(trial,into:&point) }
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) { try original.prepare(trial:&trial,work:&work,control:control) }
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) { try original.derivative(time:time,point:point,into:&output,work:&work,control:control) }
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) { try original.write(point:point,derivative:derivative,time:time,trial:&trial) }
    func validateInitial(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) { try original.validateInitial(time:time,point:point,work:&work,control:control) }
    func consistent(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState { try original.consistent(time:time,point:point,work:&work,control:control) }
    func writeAccepted(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) { try original.writeAccepted(point:point,derivative:derivative,time:time,trial:&trial,work:&work,control:control) }
}
