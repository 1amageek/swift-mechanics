import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public enum StructuralAuthoringQualificationCases {
    private typealias F = StructuralAuthoringQualificationFixtures
    public static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw StructuralAuthoringQualificationError.assertion(message) }
    }
    public static func near(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && abs(actual - expected) <= 1e-8, message)
    }
    private static func values(_ actual: [Double], _ expected: [Double], _ message: String) throws {
        try check(actual.count == expected.count, message + " shape")
        for i in actual.indices { try near(actual[i], expected[i], message + " coordinate " + String(i)) }
    }
    private static func network(_ system: StructuralMechanicalSystem) throws -> CompiledTransmissionNetwork {
        guard let value = system.transmission else { throw StructuralAuthoringQualificationError.assertion("Actual network absent") }
        return value
    }
    private static func expect(_ name: String, matches: (StructuralSystemFailure) -> Bool,
        _ operation: () throws(StructuralSystemFailure) -> Void) throws {
        var refused = false
        do throws(StructuralSystemFailure) { try operation() }
        catch { try check(matches(error), name + " returned a different typed failure"); refused = true }
        try check(refused, name + " unexpectedly succeeded")
    }
    public static func declarationLayoutAndIdentity() throws {
        let definition = try F.definition(), system = try F.compile(definition)
        let forward = try F.compile(F.definition(reverse: false))
        try check(system.model.descriptor.bodies.sorted { $0.id.key < $1.id.key } == forward.model.descriptor.bodies.sorted { $0.id.key < $1.id.key } &&
            system.model.descriptor.joints.sorted { $0.record.id.key < $1.record.id.key } == forward.model.descriptor.joints.sorted { $0.record.id.key < $1.record.id.key } &&
            system.model.descriptor.initialState == forward.model.descriptor.initialState, "Lexical declaration order changed actual records or chart")
        try check(system.layout.coordinateIDs == [101, 202] && system.layout.scales == [2, 3] && system.layout.timeScale == 5,
            "Caller coordinate identities/scales did not follow actual chart")
        try check(system.coordinateBindings.map { $0.joint } == [F.joint("a-spin"), F.joint("b-spin")], "Actual joint binding order")
        try values(system.model.descriptor.initialState.q, [0.4, -0.2], "Original q")
        try values(system.model.descriptor.initialState.v, [2, -1], "Original v")
        try values(system.drive, [6, 0], "Actual motor generalized drive")
        try check(system.source.gears.count == 1 && system.source.torques.count == 1 && system.source.passiveLaws.isEmpty,
            "Physical declarations lost source ownership")
        try check(system.motors.count == 1 && system.motors[0].rotor == F.id(.body, "a") && system.motors[0].stator == F.id(.body, "root"),
            "Relative rotor/stator identity")
        let net = try network(system)
        try check(net.id == 801 && net.modelRevision == 1 && net.physicalRows.count == 1 && net.physicalRows[0].id == 91,
            "Network original identity")
        try values(net.physicalRows[0].coefficients, [20, 40], "Original tooth coefficients")
        try near(net.physicalRows[0].phaseScale, 0.5, "Original phase scale")
        let a = try system.model.initialSnapshot.body(F.id(.body, "a"))
        let b = try system.model.initialSnapshot.body(F.id(.body, "b"))
        try near(a.motion.pose.translation.x, -2, "First parent placement once")
        try near(a.motion.pose.translation.z, -0.25, "First child anchor once")
        try near(b.motion.pose.translation.x, 2, "Second parent placement once")
        try near(b.motion.pose.translation.z, -0.25, "Second child anchor once")
    }
    public static func signedPhaseAndFrames() throws {
        for internalMesh in [false, true] {
            for antiparallel in [false, true] {
                let phase = 3.0, sign = (internalMesh ? -1.0 : 1.0) * (antiparallel ? -1.0 : 1.0)
                let system = try F.compile(F.definition(phase: phase, internalMesh: internalMesh, antiparallel: antiparallel))
                let net = try network(system), row = net.physicalRows[0]
                try values(row.coefficients, [20, sign * 40], "External/internal oriented tooth law")
                try near(row.phase, phase, "Original nonzero gear phase")
                let state = system.model.descriptor.initialState
                try near(20 * state.q[0] + sign * 40 * state.q[1], phase, "Original phase in actual q chart")
                try near(20 * state.v[0] + sign * 40 * state.v[1], 0, "Original speed in actual v chart")
                let secondJoint = try F.joint("b-spin")
                guard let port = net.ports.first(where: { $0.joint == secondJoint }) else {
                    throw StructuralAuthoringQualificationError.assertion("Original second port missing")
                }
                let axis = try port.jointToReference.rotation.rotating(.unitZ)
                try near(axis.z, antiparallel ? -1 : 1, "Actual mounted world axis")
                let b = try system.model.initialSnapshot.body(F.id(.body, "b"))
                try near(b.motion.pose.translation.x, antiparallel ? 4 : 2, "Rotated parent anchor applied once")
                try near(b.motion.pose.translation.z, antiparallel ? 0.25 : -0.25, "Rotated child anchor applied once")
                var work = try F.numerical()
                let response = try AffineTransmissionOperator().idealEfforts(net, position: state.q, velocity: state.v,
                    normalizedEnergyMultipliers: [-0.05], policy: F.systemPolicy().transmission, work: &work)
                try values(response.generalizedEfforts, [-2, -sign * 4], "Nonzero real ideal effort")
                try near(response.totalPower, 0, "Original ideal gear power")
                try near(response.originalPhaseResidual, 0, "Original physical phase acceptance")
            }
        }
    }
    public static func realMechanismAndReaction() throws {
        let authored = try F.compile(F.definition())
        let factory: any StructuralMechanismCreating = ReferenceStructuralMechanismFactory()
        let equation = try factory.equation(authored, identity: "authored-real-equation",
            policy: F.mechanismPolicy(), admission: F.admission(), maximumIdentityBytes: 65_536)
        let (system, motion) = try StructuralAuthoringQualificationMotion.reaction(authored)
        try values(system.massMatrix, [2, 0, 0, 4], "Real rigid polar mass matrix")
        try values(motion.values, [2, -1], "Independent geared acceleration")
        try values(motion.generalizedReaction, [-2, -4], "Independent geared reaction")
        try check(motion.rowIDs == [91] && motion.temporalMeaning == .accelerationForce, "Original force row meaning")
        var work = try F.numerical()
        let energy = try RigidEquationKernel().energy(system, acceleration: motion.values,
            angularMomentumReference: .zero, requireComplete: false, work: &work)
        try near(energy.kineticEnergy, 6, "Independent initial kinetic energy")
        try near(energy.kineticEnergyRate, 12, "Independent original kinetic power")
        let final = try StructuralAuthoringQualificationMotion.evolve(equation)
        try values(final.q, [0.84, -0.42], "Actual equation integrated q")
        try values(final.v, [2.4, -1.2], "Actual equation integrated v")
        try values(final.acceleration, [2, -1], "Actual equation integrated acceleration")
        let kinetic = final.v[0] * final.v[0] + 2 * final.v[1] * final.v[1]
        try near(kinetic, 8.64, "Independent endpoint kinetic energy")
        try near(kinetic - 6, 6 * (final.q[0] - 0.4), "Original torque work equals energy change")
    }
    public static func passiveLoadedEnergy() throws {
        let authored = try F.compile(F.definition(passive: true, torque: 9))
        let execution = try StationaryLoadExecution(scope: .equationExecution,
            budget: LoadBudget(maximumWork: 100_000, maximumScalars: 4096), maximumInvocations: 8, requiredScalars: 128)
        defer { _ = execution.close() }
        let factory: any StructuralMechanismCreating = ReferenceStructuralMechanismFactory()
        let equation = try factory.loadedEquation(authored, identity: "authored-loaded-equation",
            policy: F.mechanismPolicy(), admission: F.admission(), execution: execution, maximumIdentityBytes: 65_536)
        guard let selection = authored.passiveSelection else { throw StructuralAuthoringQualificationError.assertion("Passive selection absent") }
        var work = try F.numerical()
        let actual = try equation.loadedMotion(physical: authored.model.descriptor.initialState, selection: selection,
            execution: execution, work: &work)
        try values(actual.motion.values, [1, -0.5], "Original spring/damper constrained acceleration")
        try values(actual.system.forces.applied, [-6, 0], "Real passive force channel")
        let energy = try RigidEquationKernel().energy(actual.system, acceleration: actual.motion.values,
            angularMomentumReference: .zero, requireComplete: true, work: &work)
        try near(energy.kineticEnergy, 6, "Loaded kinetic energy")
        guard let potential = energy.potentialEnergy, let dissipation = energy.dissipatedPower else {
            throw StructuralAuthoringQualificationError.assertion("Known passive energy/dissipation absent")
        }
        try near(potential, 0.8, "Original spring potential")
        try near(dissipation, 4, "Original damper dissipation")
        try near(energy.kineticEnergyRate, 6, "Loaded kinetic power")
        try near(energy.kineticEnergyRate + 10 * 0.4 * 2, 9 * 2 - dissipation, "Independent complete energy rate")
        let report = execution.report()
        try check(report.invocationsStarted == 1 && report.invocationsCompleted == 1 && report.consumed > 0 &&
            !report.failedSupplierWorkUnavailable, "Actual completed passive work receipt")
    }
    public static func typedPhysicalRefusals() throws {
        let physical = try F.definition(), definitionPolicy = try F.definitionPolicy(), compilation = try F.compilation()
        var modelOnlyRefused = false
        do throws(MachineDefinitionFailure) {
            _ = try physical.makeDescriptor(definitionPolicy: definitionPolicy, compilationPolicy: compilation)
        } catch {
            if case .compilation(let failure) = error {
                try check(failure.diagnostics.contains { $0.code == .unsupportedCapability }, "Model-only typed diagnostic")
                modelOnlyRefused = true
            } else { throw error }
        }
        try check(modelOnlyRefused, "Model-only compilation silently dropped declared physics")
        let badPhase = try F.definition(inconsistentPosition: true)
        let duplicate = try F.definition(duplicateGearRow: true)
        let policy = try F.systemPolicy()
        var work = try F.numerical(), transmission = try F.numerical(), load = try F.loads(), drive = try F.actuation()
        try expect("Inconsistent actual gear phase", matches: { if case .transmission(.originalResidual(rowID: 91, value: _)) = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try badPhase.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: definitionPolicy,
                compilationPolicy: compilation, policy: policy, work: &work, transmissionWork: &transmission,
                loadWork: &load, actuationWork: &drive)
        }
        try expect("Duplicate physical row identity", matches: { if case .duplicateNumericIdentity(91) = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try duplicate.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: definitionPolicy,
                compilationPolicy: compilation, policy: policy, work: &work, transmissionWork: &transmission,
                loadWork: &load, actuationWork: &drive)
        }
        let unloaded = try F.compile(F.definition(gear: false))
        let loaded = try F.compile(F.definition(passive: true, gear: false))
        let withLaws = try F.compile(F.definition(passive: true))
        let factory: any StructuralMechanismCreating = ReferenceStructuralMechanismFactory()
        let solve = try F.mechanismPolicy(), admission = try F.admission()
        let lease = try StationaryLoadExecution(scope: .equationExecution, budget: LoadBudget(maximumWork: 100_000,
            maximumScalars: 4096), maximumInvocations: 8, requiredScalars: 128)
        defer { _ = lease.close() }
        try expect("No physical gear row", matches: { if case .missingTransmission = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try factory.equation(unloaded, identity: "no-gear", policy: solve, admission: admission, maximumIdentityBytes: 65_536)
        }
        try expect("Loaded no physical gear row", matches: { if case .missingTransmission = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try factory.loadedEquation(loaded, identity: "loaded-no-gear", policy: solve, admission: admission,
                execution: lease, maximumIdentityBytes: 65_536)
        }
        try expect("Passive law cannot be dropped", matches: { if case .requiresLoadedEquation = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try factory.equation(withLaws, identity: "cannot-drop-laws", policy: solve, admission: admission, maximumIdentityBytes: 65_536)
        }
    }
    public static func capacitiesAndRetainedWork() throws {
        let definition = try F.definition(passive: true), definitionPolicy = try F.definitionPolicy(),
            compilation = try F.compilation(), policy = try F.systemPolicy()
        for channel in 0..<4 {
            var work = try F.numerical(operations: channel == 0 ? 0 : 20_000_000)
            var transmission = try F.numerical(operations: channel == 1 ? 0 : 20_000_000)
            var load = try F.loads(operations: channel == 2 ? 0 : 100_000)
            var drive = try F.actuation(operations: channel == 3 ? 0 : 100_000)
            try expect("Declared channel budget " + String(channel), matches: { failure in
                switch (channel, failure) {
                case (0, .numerical(.resourceLimit)): return true
                case (1, .transmission(.numerical(.resourceLimit))): return true
                case (2, .loads(.workExhausted)): return true
                case (3, .actuation(.workExhausted)): return true
                default: return false
                }
            }) { () throws(StructuralSystemFailure) in
                _ = try definition.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: definitionPolicy,
                    compilationPolicy: compilation, policy: policy, work: &work, transmissionWork: &transmission,
                    loadWork: &load, actuationWork: &drive)
            }
            if channel == 0 { try check(work.operations == 0 && transmission.operations == 0 && load.consumed == 0 && drive.used == 0,
                "Failure admitted work beyond zero orchestration budget") }
            if channel > 0 { try check(work.operations > 0, "Earlier orchestration work discarded") }
            if channel == 1 { try check(transmission.operations == 0 && load.consumed == 0 && drive.used == 0, "Transmission failure visited later channels") }
            if channel >= 2 { try check(transmission.operations > 0, "Earlier transmission work discarded") }
            if channel == 2 { try check(load.consumed == 0 && drive.used == 0, "Load failure visited drive") }
            if channel == 3 { try check(load.consumed > 0 && drive.used == 0, "Earlier passive work discarded") }
        }
        let empty = try F.definitionPolicy(records: 0)
        var work = try F.numerical(), transmission = try F.numerical(), load = try F.loads(), drive = try F.actuation()
        try expect("Definition record capacity", matches: { if case .definition(.capacityExceeded) = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try definition.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: empty,
                compilationPolicy: compilation, policy: policy, work: &work, transmissionWork: &transmission,
                loadWork: &load, actuationWork: &drive)
        }
        try check(work.operations == 0 && transmission.operations == 0 && load.consumed == 0 && drive.used == 0,
            "Definition refusal consumed later supplier work")
    }
    public static func scopeAndLegacyCleanup() throws {
        let first = try F.compile(F.definition(scope: "first"), scope: "first")
        let second = try F.compile(F.definition(scope: "second"), scope: "second")
        let firstJoint = try F.joint("a-spin", scope: "first"), secondJoint = try F.joint("a-spin", scope: "second")
        try check(firstJoint != secondJoint && first.coordinateBindings[0].joint == firstJoint &&
            second.coordinateBindings[0].joint == secondJoint, "Independent namespaces share identity")
        try check(first.source.gears[0].first == firstJoint && first.source.torques[0].joint == firstJoint &&
            second.source.gears[0].first == secondJoint && second.source.torques[0].joint == secondJoint,
            "Physical local references escaped their lexical scope")
        try values(first.model.descriptor.initialState.q, [0.4, -0.2], "First scoped chart")
        try values(second.drive, [6, 0], "Second scoped actual drive")
        let unscoped = try F.compile(F.definition())
        var context = MachineDefinitionContext(policy: try F.definitionPolicy(records: 1))
        let body = MachineBody(unscoped.model.descriptor.bodies[0])
        let failing = MachineInstance(id: "failed-scope") { body }
        var failed = false
        do throws(MachineDefinitionFailure) { try context.lower(failing) }
        catch { if case .capacityExceeded = error { failed = true } else { throw error } }
        try check(failed, "Legacy nested record did not exhaust admitted identity budget")
        let original = try F.id(.body, "after-failure")
        try check(context.resolve(.local(original)) == original, "Lexical scope was not restored after child failure")
        try context.lower(EmptyMachine())
        var separate = MachineDefinitionContext(policy: try F.definitionPolicy())
        try separate.lower(MachineInstance(id: "failed-scope") { body })
        try check(separate.resolve(.local(original)) == original, "Successful legacy scope was not restored")
    }
    public static func cancelledTask() throws {
        try check(Task.isCancelled, "The Native Task was not actually cancelled")
        let definition = try F.definition(), definitionPolicy = try F.definitionPolicy(),
            compilation = try F.compilation(), policy = try F.systemPolicy()
        var work = try F.numerical(), transmission = try F.numerical(), load = try F.loads(), drive = try F.actuation()
        try expect("Actually cancelled public compiler", matches: { if case .transmission(.cancelled) = $0 { return true }; return false }) {
            () throws(StructuralSystemFailure) in
            _ = try definition.compileSystem(using: ReferenceStructuralSystemCompiler(), definitionPolicy: definitionPolicy,
                compilationPolicy: compilation, policy: policy, work: &work, transmissionWork: &transmission,
                loadWork: &load, actuationWork: &drive)
        }
        try check(work.operations == 0 && transmission.operations == 0 && load.consumed == 0 && drive.used == 0,
            "Actually cancelled compiler consumed numerical/load/actuation work")
    }
}
