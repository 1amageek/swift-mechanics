import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct SensorHingeEquation: SmoothODEEquations {
    let descriptor: ODEDescriptor
    let oscillatory: Bool
    init(model: CompiledMechanicalModel, oscillatory: Bool) throws {
        descriptor = try ODEDescriptor(identity: oscillatory ? "sensor-oscillator" : "sensor-constant-acceleration", chart: "hinge-q-v",
            model: model.stamp, dimensions: [.angle, PhysicalDimension(time: -1, angle: 1)], maximumIdentityBytes: 512, maximumCoordinates: 2)
        self.oscillatory = oscillatory
    }
    func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == descriptor.model, model.tree.layout.positionCount == 1, model.tree.layout.velocityCount == 1 else { throw RuntimeFailure(.invalidInput, message: "Test equation layout differs.") }
    }
    func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2, state.q.count == 1, state.v.count == 1 else { throw RuntimeFailure(.invalidInput, message: "Test state layout differs.") }
        point[0] = state.q[0]; point[1] = state.v[0]
    }
    func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidInput, message: "Test point layout differs.") }
        point[0] = try trial.position(at: 0); point[1] = try trial.velocity(at: 0)
    }
    func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) { try charge(&work, 1) }
    func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1); try charge(&work, 2)
        guard point.count == 2, output.count == 2 else { throw RuntimeFailure(.invalidInput, message: "Test derivative layout differs.") }
        output[0] = point[1]; output[1] = oscillatory ? -point[0] : 2
    }
    func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure) {
        try trial.setPosition(point[0], at: 0); try trial.setVelocity(point[1], at: 0); try trial.setAcceleration(derivative[1], at: 0); try trial.setTime(time)
    }
    private func charge(_ work: inout NumericalWork, _ count: Int) throws(RuntimeFailure) {
        do { try work.chargeOperations(count) } catch { throw RuntimeFailure(.capacityExceeded, message: "Test numerical work exhausted.") }
    }
}
