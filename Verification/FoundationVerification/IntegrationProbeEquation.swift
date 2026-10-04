import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct IntegrationProbeEquation: SmoothODEEquations {
    let descriptor: ODEDescriptor
    let malformed: Bool
    let nestedFailure: Bool

    init(model: CompiledMechanicalModel, malformed: Bool = false, nestedFailure: Bool = false) throws(RuntimeFailure) {
        descriptor = try ODEDescriptor(identity: "constant-angular-acceleration", chart: "hinge-q-v", model: model.stamp,
            dimensions: [.angle, PhysicalDimension(time: -1, angle: 1)], maximumIdentityBytes: 256, maximumCoordinates: 2)
        self.malformed = malformed; self.nestedFailure = nestedFailure
    }
    func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == descriptor.model, model.tree.layout.positionCount == 1, model.tree.layout.velocityCount == 1,
              model.tree.joints.count == 1, model.tree.joints[0].manifold.kind == .revolute else {
            throw RuntimeFailure(.unsupportedDomain, message: "Probe equation requires one revolute coordinate.")
        }
    }
    func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2, state.q.count == 1, state.v.count == 1 else {
            throw RuntimeFailure(.invalidState, message: "Probe physical coordinate count mismatch.")
        }
        point[0] = state.q[0]; point[1] = state.v[0]
    }
    func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidState, message: "Probe trial chart count mismatch.") }
        point[0] = try trial.position(at: 0); point[1] = try trial.velocity(at: 0)
    }
    func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try charge(&work, 1); _ = try trial.nextRandom()
    }
    func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1); try charge(&work, 2)
        guard time.isFinite, point.count == 2, output.count == 2 else { throw RuntimeFailure(.invalidState, message: "Probe derivative layout mismatch.") }
        if nestedFailure { throw RuntimeFailure(.invalidState, message: "Actual derivative charged work before nested supplier evidence became unavailable.", failedSupplierWorkUnavailable: true) }
        output[0] = point[1]
        if !malformed { output[1] = 2 }
    }
    func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure) {
        try trial.setPosition(point[0], at: 0); try trial.setVelocity(point[1], at: 0)
        try trial.setAcceleration(derivative[1], at: 0); try trial.setTime(time)
    }
    private func charge(_ work: inout NumericalWork, _ count: Int) throws(RuntimeFailure) {
        do { try work.chargeOperations(count) }
        catch { throw RuntimeFailure(.capacityExceeded, message: "Probe supplier work exhausted.") }
    }
}
