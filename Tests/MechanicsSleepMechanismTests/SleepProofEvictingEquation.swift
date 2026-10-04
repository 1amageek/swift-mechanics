import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct SleepProofEvictingEquation:SmoothODEEquations,Sendable {
    let base:any SmoothODEEquations
    let owner:CheckpointedMechanismSleep
    let other:any RuntimeSessionOperating
    var descriptor:ODEDescriptor { base.descriptor }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) { try base.validate(model:model) }
    func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) { try base.read(state,into:&point) }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) { try base.read(trial,into:&point) }
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try base.prepare(trial:&trial,work:&work,control:control)
        do throws(MechanismSleepFailure) { _=try owner.step(other) }
        catch { throw RuntimeFailure(.invalidState,message:"Independent physical session could not evict the shared memo.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
    }
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try base.derivative(time:time,point:point,into:&output,work:&work,control:control)
    }
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        try base.write(point:point,derivative:derivative,time:time,trial:&trial)
    }
}
