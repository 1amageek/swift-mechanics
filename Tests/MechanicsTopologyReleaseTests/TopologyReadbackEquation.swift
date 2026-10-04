import SwiftMechanics

/// A test chart used only for explicit integration-history initialization and association.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
struct TopologyReadbackEquation: SmoothODEEquations {
    let model:CompiledMechanicalModel
    let descriptor:ODEDescriptor
    init(model:CompiledMechanicalModel) throws {
        self.model=model
        descriptor=try ODEDescriptor(identity:"topology-readback",chart:"q-v-\(model.stamp.revision)",model:model.stamp,
            dimensions:[PhysicalDimension](repeating:.dimensionless,count:model.tree.layout.positionCount+model.tree.layout.velocityCount),
            maximumIdentityBytes:256,maximumCoordinates:128)
    }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == self.model.stamp,model.descriptor == self.model.descriptor else { throw RuntimeFailure(.incompatibleModel,message:"Readback chart has another model.") }
    }
    func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) {
        do throws(CompilationFailure) { _=try model.makeState(state) }
        catch { throw RuntimeFailure(.invalidState,message:"Readback physical state failed actual compiler admission.") }
        guard point.count == descriptor.dimensions.count else { throw RuntimeFailure(.invalidInput,message:"Readback point capacity differs.") }
        for i in state.q.indices { point[i]=state.q[i] }
        for i in state.v.indices { point[state.q.count+i]=state.v[i] }
    }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) {
        throw RuntimeFailure(.invalidInput,message:"This history-only fixture does not evolve trials.")
    }
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        throw RuntimeFailure(.invalidInput,message:"This history-only fixture does not evolve trials.")
    }
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        throw RuntimeFailure(.invalidInput,message:"This history-only fixture does not evolve trials.")
    }
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        throw RuntimeFailure(.invalidInput,message:"This history-only fixture does not evolve trials.")
    }
}
