import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ImplicitQualificationODE: ImplicitODEEquations, Sendable {
    public let descriptor: ODEDescriptor
    public let implicitDomain: ImplicitEquationDomain
    public let physics: ImplicitQualificationPhysics
    public let fault: ImplicitQualificationFault
    public let onDerivative: (@Sendable () -> Void)?
    public init(model: CompiledMechanicalModel, physics: ImplicitQualificationPhysics,
                fault: ImplicitQualificationFault = .none, domain: ImplicitEquationDomain = .smoothEuclidean,
                onDerivative: (@Sendable () -> Void)? = nil) throws(RuntimeFailure) {
        descriptor = try ODEDescriptor(identity: "implicit-original-prismatic-ODE", chart: "prismatic-SI-q-v",
            model: model.stamp, dimensions: [.length, PhysicalDimension(length: 1, time: -1)],
            maximumIdentityBytes: 256, maximumCoordinates: 2)
        self.physics = physics; self.fault = fault; implicitDomain = domain; self.onDerivative = onDerivative
    }
    public func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard descriptor.model == model.stamp && model.descriptor.bodies.count == 2 && model.tree.rootBase == .fixed && model.tree.joints.count == 1
            && model.tree.layout.positionCount == 1 && model.tree.layout.velocityCount == 1 else {
            throw RuntimeFailure(.unsupportedDomain, message: "Original fixture requires the declared single fixed-base prismatic chart.")
        }
        guard case .prismatic = model.tree.joints[0].manifold.kind,
              let movingBody = model.descriptor.bodies.first(where: { $0.id == model.tree.joints[0].childBody }),
              case .spatial(let body) = movingBody, let inertia = body.inertia,
              inertia.properties.mass == physics.mass else {
            throw RuntimeFailure(.invalidInput, message: "Actual compiler-admitted body inertia must match the declared physical law.")
        }
    }
    public func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 && state.q.count == 1 && state.v.count == 1 else { throw RuntimeFailure(.invalidInput, message: "Declared ODE chart shape.") }
        point[0] = state.q[0]; point[1] = state.v[0]
    }
    public func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidInput, message: "Declared trial chart shape.") }
        point[0] = try trial.position(at: 0); point[1] = try trial.velocity(at: 0)
    }
    public func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try charge(&work, 1); try control.beginWorkBlock(units: 1)
        _ = try trial.nextRandom()
        let record = try trial.contributor("implicit-physical-preparation")
        guard record.bytes.count == 1 && record.bytes[0] < UInt8.max else { throw RuntimeFailure(.invalidContributor, message: "Preparation counter capacity.") }
        try trial.replaceContributor(RuntimeContributorState(id: record.id, category: record.category, version: record.version, bytes: [record.bytes[0]+1]))
        if fault == .preparePhysicalMutation { try trial.setPosition(2, at: 0) }
        if fault == .prepareFailure { throw RuntimeFailure(.invalidState, message: "Declared preparation failure after physical subsystem preparation.") }
    }
    public func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork,
                           control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1); try charge(&work, 16)
        guard time.isFinite && point.count == 2 && output.count == 2 else { throw RuntimeFailure(.invalidState, message: "Physical derivative shape/time.") }
        if fault == .resetLedger { work = NumericalWork(budget: work.budget) }
        if fault == .unavailableFailure { throw RuntimeFailure(.invalidState, message: "Declared failed opaque nested supplier.", failedSupplierWorkUnavailable: true) }
        onDerivative?()
        let force = try physics.loadResponse(q: point[0], v: point[1])
        output[0] = point[1]
        if fault != .missingDerivative { output[1] = (physics.constantLoad+force.conservative+force.dissipative)/physics.mass }
    }
    public func derivativeJacobian(time: Double, point: [Double], into rowMajorOutput: inout [Double],
                                   work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1); try charge(&work, 16)
        guard point.count == 2 && rowMajorOutput.count == 4 else { throw RuntimeFailure(.invalidState, message: "Physical derivative tangent shape.") }
        let force = try physics.loadResponse(q: point[0], v: point[1])
        rowMajorOutput[0] = 0; rowMajorOutput[1] = 1
        rowMajorOutput[2] = fault == .wrongTangent ? 0 : force.coordinateDerivative/physics.mass
        rowMajorOutput[3] = force.rateDerivative/physics.mass
    }
    public func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure) {
        guard point.count == 2 && derivative.count == 2 else { throw RuntimeFailure(.invalidState, message: "Physical endpoint write shape.") }
        try trial.setPosition(point[0]+(fault == .writeMismatch ? 0.01 : 0), at: 0)
        try trial.setVelocity(point[1], at: 0); try trial.setAcceleration(derivative[1], at: 0); try trial.setTime(time)
    }
    private func charge(_ work: inout NumericalWork, _ amount: Int) throws(RuntimeFailure) {
        do throws(NumericalError) { try work.chargeOperations(amount) }
        catch { throw RuntimeFailure(.capacityExceeded, message: "Declared physical provider numerical work exhausted.") }
    }
}
