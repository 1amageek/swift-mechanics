import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ManufacturedHingeEquation: SmoothODEEquations {
    enum LedgerFault: Equatable, Sendable { case none, replaceInPrepare, resetInDerivative, nestedFailure }
    let descriptor: ODEDescriptor
    let accelerationCoefficient: Double
    let malformed: Bool
    let prepareSubsystem: Bool
    let ledgerFault: LedgerFault
    let onDerivative: (@Sendable () -> Void)?
    init(model: CompiledMechanicalModel, coefficient: Double = -1, malformed: Bool = false, prepareSubsystem: Bool = false, ledgerFault: LedgerFault = .none, onDerivative: (@Sendable () -> Void)? = nil) throws {
        descriptor = try ODEDescriptor(identity: "manufactured-hinge-" + String(coefficient), chart: "revolute-q-angular-v", model: model.stamp,
            dimensions: [.angle,PhysicalDimension(time: -1,angle: 1)], maximumIdentityBytes: 256, maximumCoordinates: 2)
        accelerationCoefficient = coefficient; self.malformed = malformed; self.prepareSubsystem = prepareSubsystem; self.ledgerFault = ledgerFault; self.onDerivative = onDerivative
    }
    func validate(model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == descriptor.model, model.tree.layout.positionCount == 1, model.tree.layout.velocityCount == 1,
              model.tree.rootBase == .fixed, model.tree.joints.count == 1 else { throw RuntimeFailure(.unsupportedDomain, message: "Fixture admits only one fixed-root Euclidean hinge chart.") }
        if case .revolute = model.tree.joints[0].manifold.kind {} else { throw RuntimeFailure(.unsupportedDomain, message: "Fixture chart requires revolute coordinate.") }
    }
    func read(_ state: KinematicState, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2, state.q.count == 1, state.v.count == 1 else { throw RuntimeFailure(.invalidInput, message: "Fixture chart layout mismatch.") }
        point[0] = state.q[0]; point[1] = state.v[0]
    }
    func read(_ trial: RuntimeTrial, into point: inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidInput, message: "Fixture point count mismatch.") }
        point[0] = try trial.position(at: 0); point[1] = try trial.velocity(at: 0)
    }
    func prepare(trial: inout RuntimeTrial, work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try charge(&work, 1)
        if prepareSubsystem {
            _ = try trial.nextRandom()
            let old = try trial.contributor("actuation-counter")
            guard old.bytes.count == 1, old.bytes[0] < UInt8.max else { throw RuntimeFailure(.invalidContributor, message: "Fixture subsystem counter invalid.") }
            try trial.replaceContributor(RuntimeContributorState(id: old.id, category: old.category, version: old.version, bytes: [old.bytes[0]+1]))
        }
        if ledgerFault == .replaceInPrepare {
            do { work = NumericalWork(budget: try NumericalBudget(scalarStorage: 0, arithmeticOperations: 0, iterations: 0)) }
            catch { throw RuntimeFailure(.invalidInput, message: "Fixture replacement budget construction failed.") }
        }
    }
    func derivative(time: Double, point: [Double], into output: inout [Double], work: inout NumericalWork, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1); try charge(&work, 2)
        if ledgerFault == .resetInDerivative { work = NumericalWork(budget: work.budget) }
        if ledgerFault == .nestedFailure { throw RuntimeFailure(.invalidState, message: "Nested supplier failed after charged work without complete nested ledger.", failedSupplierWorkUnavailable: true) }
        onDerivative?()
        guard time.isFinite, point.count == 2, output.count == 2 else { throw RuntimeFailure(.invalidState, message: "Fixture derivative domain invalid.") }
        output[0] = point[1]
        if !malformed { output[1] = accelerationCoefficient*point[0] }
    }
    func write(point: [Double], derivative: [Double], time: Double, trial: inout RuntimeTrial) throws(RuntimeFailure) {
        try trial.setPosition(point[0],at: 0); try trial.setVelocity(point[1],at: 0); try trial.setAcceleration(derivative[1],at: 0); try trial.setTime(time)
    }
    private func charge(_ work: inout NumericalWork, _ operations: Int) throws(RuntimeFailure) {
        do { try work.chargeOperations(operations) }
        catch { throw RuntimeFailure(.capacityExceeded, message: "Fixture supplier arithmetic exhausted.") }
    }
}
