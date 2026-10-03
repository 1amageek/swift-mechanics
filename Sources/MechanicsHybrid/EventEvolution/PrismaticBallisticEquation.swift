import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints
import MechanicsNumerics
import MechanicsRuntime
import MechanicsIntegration

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct PrismaticBallisticEquation: SmoothODEEquations {
    public let descriptor: ODEDescriptor
    public let accelerationMetersPerSecondSquared: Double
    public let cancellation: HybridCancellation
    public init(model: CompiledMechanicalModel, accelerationMetersPerSecondSquared: Double,
                cancellation: HybridCancellation, maximumIdentityBytes: Int) throws(RuntimeFailure) {
        guard accelerationMetersPerSecondSquared.isFinite, accelerationMetersPerSecondSquared < 0 else { throw RuntimeFailure(.unsupportedDomain,message:"Ballistic chart admits constant downward acceleration.") }
        self.accelerationMetersPerSecondSquared=accelerationMetersPerSecondSquared; self.cancellation=cancellation
        descriptor=try ODEDescriptor(identity:"hybrid.ballistic."+String(accelerationMetersPerSecondSquared.bitPattern),chart:"fixed-root-world-z-prismatic-q-v",model:model.stamp,
            dimensions:[.length,PhysicalDimension(length:1,time:-1)],maximumIdentityBytes:maximumIdentityBytes,maximumCoordinates:2)
        try validate(model:model)
    }
    public func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == descriptor.model, model.tree.rootBase == .fixed, model.tree.bodies.count == 2,
              model.tree.joints.count == 1, model.tree.layout.positionCount == 1, model.tree.layout.velocityCount == 1,
              model.tree.joints[0].manifold.kind == .prismatic,
              model.tree.joints[0].manifold.orderedAxes.count == 1, model.tree.joints[0].manifold.orderedAxes[0].direction == .unitZ else { throw RuntimeFailure(.unsupportedDomain,message:"Ballistic chart requires a fixed-root spatial world-z prismatic body.") }
        let root=model.tree.bodies[0].id, child=model.tree.bodies[1].id
        guard let rootRecord=model.descriptor.bodies.first(where: { $0.id == root }), let childRecord=model.descriptor.bodies.first(where: { $0.id == child }),
              case .spatial(let a)=rootRecord, case .spatial(let b)=childRecord, a.mode == .static, b.mode == .dynamic,
              model.tree.joints[0].parentBody == root, model.tree.joints[0].childBody == child,
              model.descriptor.joints[0].authority == .dynamicState else { throw RuntimeFailure(.unsupportedDomain,message:"Ballistic coordinate/body authorities differ.") }
        guard a.bodyToWorld.rotation == .identity, b.bodyToWorld.rotation == .identity,
              model.tree.joints.allSatisfy({ joint in
                  if case .fixed(let pa)=joint.parentAnchor.placement, case .fixed(let pb)=joint.childAnchor.placement { return pa.rotation == .identity && pb.rotation == .identity }; return false
              }) else { throw RuntimeFailure(.unsupportedDomain,message:"Ballistic chart requires fixed aligned anchors.") }
    }
    public func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        guard state.revision == descriptor.model.revision, state.q.count == 1, state.v.count == 1, point.count == 2 else { throw RuntimeFailure(.invalidState,message:"Ballistic coordinate layout differs.") }
        point[0]=state.q[0]; point[1]=state.v[0]
    }
    public func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidState,message:"Ballistic coordinate buffer differs.") }
        point[0]=try trial.position(at:0); point[1]=try trial.velocity(at:0)
    }
    public func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try check(); try control.beginWorkBlock(units:1); try charge(&work,units:1)
        // This equation is stateless: preparation certifies cancellation and charges its work, without changing contributors/RNG.
    }
    public func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try check(); try control.beginWorkBlock(units:1); try charge(&work,units:2)
        guard time.isFinite, point.count == 2, output.count == 2, point.allSatisfy({ $0.isFinite }) else { throw RuntimeFailure(.invalidState,message:"Ballistic derivative input invalid.") }
        output[0]=point[1]; output[1]=accelerationMetersPerSecondSquared
    }
    public func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure) {
        guard point.count == 2, derivative.count == 2 else { throw RuntimeFailure(.invalidState,message:"Ballistic output layout differs.") }
        try check(); try trial.setPosition(point[0],at:0); try trial.setVelocity(point[1],at:0)
        try trial.setAcceleration(derivative[1],at:0); try trial.setTime(time)
    }
    private func check() throws(RuntimeFailure) {
        guard !cancellation.isCancelled, !Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Ballistic equation cancelled.") }
    }
    private func charge(_ work: inout NumericalWork, units: Int) throws(RuntimeFailure) {
        do { try work.chargeOperations(units) } catch { throw RuntimeFailure(.capacityExceeded,message:"Ballistic derivative numerical budget exhausted.") }
    }
}
