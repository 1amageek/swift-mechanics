import SwiftMechanics

public enum TaskSpaceQualificationCases {
    private static func require(_ condition: Bool, _ message: String) throws(TaskSpaceQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String) throws(TaskSpaceQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual - expected) <= 1e-8 * max(1, abs(expected)), message)
    }
    private static func close(_ actual: [Double], _ expected: [Double], _ message: String) throws(TaskSpaceQualificationError) {
        try require(actual.count == expected.count, message + " shape")
        for i in expected.indices { try close(actual[i], expected[i], message) }
    }
    private static func close(_ actual: Vector3, _ expected: Vector3, _ message: String) throws(TaskSpaceQualificationError) {
        try close([actual.x, actual.y, actual.z], [expected.x, expected.y, expected.z], message)
    }
    private static func expect(_ message: String, _ predicate: (TaskSpaceFailure) -> Bool,
                               _ operation: () throws(TaskSpaceFailure) -> Void) throws(TaskSpaceQualificationError) {
        do throws(TaskSpaceFailure) { try operation() }
        catch {
            guard predicate(error) else { throw .unexpectedFailure(error) }
            return
        }
        throw .unexpectedSuccess(message)
    }
    private static func component(_ value: Vector3, _ axis: TaskSpaceAxis) -> Double {
        switch axis { case .x: value.x; case .y: value.y; case .z: value.z }
    }
    private static func execute(_ fixture: TaskSpaceQualificationFixture, position: [Double], system: PhysicalRigidDynamicsSystem,
                                command: TaskSpaceRequest.Command, policy: TaskSpacePolicy) throws -> TaskSpaceResult {
        let controller: any TaskSpaceControlling = ReferenceTaskSpaceController()
        var work = try TaskSpaceQualificationFixture.work(seeded: true)
        let request = fixture.request(system, command)
        let result = try controller.evaluate(request, policy: policy, work: &work)
        try require(result.request.system === system && result.physicalResponse.system === system,
                    "Returned result must retain exact original physical source")
        try require(result.diagnostics.work == work && work.operations > 11 && work.iterations > 1,
                    "Actual success must retain the caller's seeded cumulative work")
        try require(result.physicalResponse.originalPhysicalResidual.isAccepted &&
                    result.physicalResponse.originalPhysicalResidual.equation == .completeInertiaAndKnownLoads,
                    "Actual response must accept original complete Newton/Euler equation")
        try close(result.diagnostics.virtualPowerResidualWatts, 0, "Original virtual-power residual")
        try close(result.diagnostics.taskDualPrescribedPowerWatts, 0, "Admitted fixed-anchor domain has zero drift power")
        try reconstruct(fixture, result, position: position)
        return result
    }

    private static func reconstruct(_ fixture: TaskSpaceQualificationFixture, _ result: TaskSpaceResult, position: [Double]) throws {
        let system = result.request.system, original = system.input.snapshot
        let state = try fixture.model.makeState(KinematicState(revision: original.tree.revision, time: original.time,
            q: position, v: system.input.velocity, acceleration: result.physicalResponse.acceleration))
        let after = try fixture.model.evaluate(state)
        try require(after.tree.revision == original.tree.revision && after.time == original.time &&
                    after.tree.worldFrame == original.tree.worldFrame, "Fresh physical reconstruction preserves original source/frame/time")
        try require(after.bodies.count == original.bodies.count, "Fresh original body shape")
        for i in original.bodies.indices {
            try require(after.bodies[i].body == original.bodies[i].body && after.bodies[i].motion.pose == original.bodies[i].motion.pose,
                        "Fresh reconstruction must retain exact original caller position and physical body pose")
        }
        if case .pointMotion(let task) = result.request.command {
            let point = try KinematicJacobianCalculator().pointMotion(body: task.body, bodyLocalPoint: task.bodyLocalPoint, snapshot: after)
            for i in task.axes.indices {
                try close(component(point.acceleration, task.axes[i]), result.diagnostics.achievedTaskAcceleration[i],
                          "Fresh original post-command point acceleration")
            }
        }
        var work = try TaskSpaceQualificationFixture.work()
        var force = [Double](repeating: 0, count: fixture.count)
        try RigidEquationKernel().originalInertialForce(system, acceleration: result.physicalResponse.acceleration,
            includeBias: true, into: &force, work: &work)
        var power = 0.0
        for i in force.indices {
            let known = try system.forces.total(at: i)
            try close(force[i], result.generalizedEffort[i] + known, "Fresh original body Newton/Euler balance")
            power += force[i] * system.input.velocity[i]
        }
        let energy = try RigidEquationKernel().energy(system, acceleration: result.physicalResponse.acceleration,
            angularMomentumReference: .zero, requireComplete: false, work: &work)
        try close(energy.kineticEnergyRate, power, "Original kinetic rate equals generalized total force power")
        try close(energy.requiredVirtualPower, power, "Original required virtual power")
        try close(energy.requiredPrescribedPower, 0, "Original fixed-root prescribed power")
    }

    private static func energy(_ result: TaskSpaceResult) throws -> MechanicalEnergy {
        var work = try TaskSpaceQualificationFixture.work()
        return try RigidEquationKernel().energy(result.request.system, acceleration: result.physicalResponse.acceleration,
            angularMomentumReference: .zero, requireComplete: false, work: &work)
    }

    public static func serialPriority() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX), .prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0.2, 0.3], velocity: [2, -1])
        try close(system.massMatrix, [5, 3, 3, 3], "Independent serial slider mass in kilograms")
        let task = fixture.motion(axes: [.x], acceleration: [4], weights: [9], secondary: [5, 7])
        let result = try execute(fixture, position: [0.2, 0.3], system: system, command: .pointMotion(task), policy: fixture.policy())
        let d = result.diagnostics
        try require(d.taskRank == 1 && d.usesExactDynamicallyConsistentInverse && d.damping == 0,
                    "Strict selected primary must use the exact mass-consistent inverse")
        try close(d.primaryAcceleration, [0, 4], "Independent primary acceleration")
        try close(d.projectedSecondaryAcceleration, [5, -5], "Independent dynamic nullspace secondary")
        try close(result.physicalResponse.acceleration, [5, -1], "Actual combined generalized acceleration")
        try close(result.generalizedEffort, [22, 12], "Independent generalized drive forces in newtons")
        try close(d.achievedTaskAcceleration, [4], "Primary remains achieved after secondary")
        try close(d.primaryTaskResidual, [0], "Strict original primary residual")
        try close(d.secondaryTaskLeak, [0], "Exact secondary has zero original task leak")
        try close(d.regularizationDefect, [0], "Exact primary has no introduced damping defect")
        try close(d.secondaryRegularizationDefect, [0], "Exact secondary has no introduced damping defect")
        guard let force = d.pointTaskDualForceNewtons else { throw TaskSpaceQualificationError.assertion("Motion dual force missing") }
        try close(force, Vector3(12, 0, 0), "Task dual is primary-only physical point force")
        try close(d.generalizedDrivePowerWatts, 32, "Drive and secondary power")
        try close(d.taskDualVirtualPowerWatts, 12, "Primary-only task dual power")
        try close(d.taskDualActualPowerWatts, 12, "Fixed-anchor actual dual power")
        let e = try energy(result)
        try close(e.kineticEnergy, 5.5, "Independent serial slider kinetic energy")
        try close(e.kineticEnergyRate, 32, "Independent serial slider kinetic rate")
    }

    public static func weightedScaledAxes() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX), .prismatic(axis: .unitY)])
        let system = try fixture.system(position: [0.2, 0.3], velocity: [2, -1])
        try close(system.massMatrix, [5, 0, 0, 3], "Independent orthogonal slider mass")
        let point = try KinematicJacobianCalculator().point(body: fixture.body, bodyLocalPoint: .zero, snapshot: system.input.snapshot)
        try require(point.columns.count == 2, "Actual original point row layout")
        try close(point.columns[0], .unitX, "Original X coordinate row")
        try close(point.columns[1], .unitY, "Original Y coordinate row")
        let task = fixture.motion(axes: [.x, .y], acceleration: [4, -2], weights: [9, 0.25])
        let policy = try fixture.policy(coordinateScales: [0.25, 2], energyScale: 7, timeScale: 3, lengthScale: 0.5)
        let result = try execute(fixture, position: [0.2, 0.3], system: system, command: .pointMotion(task), policy: policy)
        try require(result.diagnostics.taskRank == 2 && result.diagnostics.usesExactDynamicallyConsistentInverse,
                    "Distinct weighted axes preserve full rank")
        try close(result.physicalResponse.acceleration, [4, -2], "Nonunit normalization preserves SI acceleration")
        try close(result.generalizedEffort, [20, -6], "Nonunit normalization preserves SI effort")
        try close(result.diagnostics.achievedTaskAcceleration, [4, -2], "Both weighted rows achieved")
        guard let force = result.diagnostics.pointTaskDualForceNewtons else { throw TaskSpaceQualificationError.assertion("Weighted dual force missing") }
        try close(force, Vector3(20, -6, 0), "Independent weighted SI point force")
        try close(result.diagnostics.generalizedDrivePowerWatts, 46, "Independent weighted SI power")
        try close(result.diagnostics.taskDualActualPowerWatts, 46, "Independent point virtual work")
        let e = try energy(result)
        try close(e.kineticEnergy, 11.5, "Independent orthogonal slider kinetic energy")
        try close(e.kineticEnergyRate, 46, "Independent orthogonal slider kinetic rate")
    }

    public static func hingeBiasAndGravity() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.revolute(axis: .unitZ)], hingeCenter: true)
        let system = try fixture.system(position: [0], velocity: [3], gravity: Vector3(0, -10, 0))
        try close(system.massMatrix, [3], "Independent hinge COM parallel-axis inertia")
        try close(system.inertialBias, [0], "Radial centripetal force has no hinge generalized torque")
        try close(system.forces.total(at: 0), -20, "Uniform gravity original COM moment")
        let point = try Vector3(2, 0, 0)
        let motion = try KinematicJacobianCalculator().pointMotion(body: fixture.body, bodyLocalPoint: point, snapshot: system.input.snapshot)
        try close(motion.accelerationBias, Vector3(-18, 0, 0), "Independent rotational point centripetal bias")
        try close(motion.velocity, Vector3(0, 6, 0), "Independent physical point velocity")
        let result = try execute(fixture, position: [0], system: system,
            command: .pointMotion(fixture.motion(axes: [.y], acceleration: [4], weights: [1], point: point)), policy: fixture.policy())
        try close(result.physicalResponse.acceleration, [2], "Hinge generalized angular acceleration in radians per second squared")
        try close(result.generalizedEffort, [26], "Hinge generalized effort in newton meters includes original gravity compensation")
        guard let force = result.diagnostics.pointTaskDualForceNewtons else { throw TaskSpaceQualificationError.assertion("Hinge dual force missing") }
        try close(force, Vector3(0, 3, 0), "Independent hinge point dual force")
        try close(result.diagnostics.generalizedDrivePowerWatts, 78, "Compensated drive power")
        try close(result.diagnostics.taskDualActualPowerWatts, 18, "Task dual excludes gravity compensation")
        let e = try energy(result)
        try close(e.kineticEnergy, 13.5, "Independent hinge kinetic energy")
        try close(e.kineticEnergyRate, 18, "Independent hinge kinetic rate")
        try close(e.kineticEnergyRate + 60, result.diagnostics.generalizedDrivePowerWatts,
                  "Original uniform gravity potential rate and kinetic rate close drive power")
    }

    public static func additionalWrenchPower() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let known = try GeneralizedForceContribution(values: [10], channel: .applied, potentialEnergy: 0, dissipatedPower: 0)
        let system = try fixture.system(position: [0.4], velocity: [2], knownForces: [known])
        let origin = try system.input.snapshot.body(fixture.body).motion.pose.translation
        let command = TaskSpaceWrench(body: fixture.body, referencePointWorld: origin,
            wrench: SpatialWrench(torque: .zero, force: try Vector3(6, 0, 0)))
        let policy = try fixture.policy()
        let forceResult = try execute(fixture, position: [0.4], system: system, command: .bodyOriginWrench(command), policy: policy)
        try close(forceResult.generalizedEffort, [6], "Additional wrench maps through original J transpose")
        try close(forceResult.physicalResponse.acceleration, [8], "Known and additional actual force determine acceleration")
        try require(forceResult.diagnostics.taskRank == nil && !forceResult.diagnostics.usesExactDynamicallyConsistentInverse &&
                    forceResult.diagnostics.pointTaskDualForceNewtons == nil && forceResult.diagnostics.achievedTaskAcceleration.isEmpty,
                    "Force command must not masquerade as a point acceleration command")
        try close(forceResult.diagnostics.generalizedDrivePowerWatts, 12, "Additional physical force power")
        try close(forceResult.diagnostics.taskDualActualPowerWatts, 12, "Additional body-origin virtual power")
        let e = try energy(forceResult)
        try close(e.kineticEnergy, 4, "Independent slider kinetic energy")
        try close(e.kineticEnergyRate, 32, "Known plus commanded force kinetic rate")
        try close(e.kineticEnergyRate - 20, forceResult.diagnostics.generalizedDrivePowerWatts, "Known load power remains separate")
        let motionResult = try execute(fixture, position: [0.4], system: system,
            command: .pointMotion(fixture.motion(axes: [.x], acceleration: [8], weights: [1])), policy: policy)
        try close(motionResult.generalizedEffort, [6], "Motion inverse compensates known load")
        guard let dual = motionResult.diagnostics.pointTaskDualForceNewtons else { throw TaskSpaceQualificationError.assertion("Motion dual missing") }
        try close(dual.x, 16, "Motion primary mass dual differs from additional drive effort")
        try close(motionResult.diagnostics.taskDualActualPowerWatts, 32, "Motion mass dual power")
        try close(motionResult.diagnostics.generalizedDrivePowerWatts, 12, "Motion actual drive power excludes known load")
    }

    public static func rankDampingAndGates() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0], velocity: [2])
        let task = fixture.motion(axes: [.x, .y], acceleration: [4, 0], weights: [1, 7], secondary: [6])
        let request = fixture.request(system, .pointMotion(task)), controller: any TaskSpaceControlling = ReferenceTaskSpaceController()
        var strictWork = try TaskSpaceQualificationFixture.work()
        let strict = try fixture.policy()
        try expect("Strict singular task", { if case .singularTask(rank: 1, rows: 2) = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: strict, work: &strictWork)
        }
        try require(strictWork.operations > 0, "Strict rank refusal retains original mass-query work")
        let accepted = try fixture.policy(singularity: .damped(lambda: 0.5), taskAbsolute: 2, leakAbsolute: 2.1, taskRelative: 0)
        let result = try execute(fixture, position: [0], system: system, command: .pointMotion(task), policy: accepted)
        let d = result.diagnostics
        try require(d.taskRank == 1 && !d.usesExactDynamicallyConsistentInverse && d.damping == 0.5,
                    "Damped rank-deficient law must not claim exact dynamic inverse")
        try close(d.primaryAcceleration, [8.0 / 3], "Independent damped primary")
        try close(d.projectedSecondaryAcceleration, [2], "Independent introduced secondary leak")
        try close(result.physicalResponse.acceleration, [14.0 / 3], "Independent damped total acceleration")
        try close(result.generalizedEffort, [28.0 / 3], "Independent damped effort")
        try close(d.primaryTaskResidual, [-4.0 / 3, 0], "Original primary error remains visible")
        try close(d.secondaryTaskLeak, [2, 0], "Original secondary error remains visible")
        try close(d.taskResidual, [2.0 / 3, 0], "Original total error remains visible")
        try close(d.regularizationDefect, [4.0 / 3, 0], "Independent primary regularization defect")
        try close(d.secondaryRegularizationDefect, [2, 0], "Independent secondary regularization defect")
        let primaryGate = try fixture.policy(singularity: .damped(lambda: 0.5), taskAbsolute: 1, leakAbsolute: 2.1, taskRelative: 0)
        var primaryWork = try TaskSpaceQualificationFixture.work()
        try expect("Damping primary error must pass its own gate", { if case .taskResidualRejected = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: primaryGate, work: &primaryWork)
        }
        let leakGate = try fixture.policy(singularity: .damped(lambda: 0.5), taskAbsolute: 2, leakAbsolute: 1.5, taskRelative: 0)
        var leakWork = try TaskSpaceQualificationFixture.work()
        try expect("Damping secondary leak must pass its own gate", { if case .secondaryLeakRejected = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: leakGate, work: &leakWork)
        }
    }

    public static func sourceDomainShapeRefusals() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0], velocity: [2]), policy = try fixture.policy()
        let task = fixture.motion(axes: [.x], acceleration: [4], weights: [1])
        let controller: any TaskSpaceControlling = ReferenceTaskSpaceController()
        for request in [fixture.request(system, .pointMotion(task), revision: 2), fixture.request(system, .pointMotion(task), time: 4)] {
            var work = try TaskSpaceQualificationFixture.work()
            try expect("Original revision/time binding", { if case .staleSource = $0.cause { true } else { false } }) {
                () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &work)
            }
        }
        var frameWork = try TaskSpaceQualificationFixture.work()
        let wrongFrame = fixture.request(system, .pointMotion(task), frame: try EntityID(kind: .frame, key: "other-world"))
        try expect("Original world frame binding", { if case .frameMismatch = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(wrongFrame, policy: policy, work: &frameWork)
        }
        let origin = try system.input.snapshot.body(fixture.body).motion.pose.translation
        let wrench = TaskSpaceWrench(body: fixture.body, referencePointWorld: origin,
            wrench: SpatialWrench(torque: .zero, force: .unitX))
        let wrongOrigin = TaskSpaceWrench(body: fixture.body, referencePointWorld: try origin.adding(.unitY), wrench: wrench.wrench)
        let requests: [(TaskSpaceRequest, Int)] = [
            (fixture.request(system, .bodyOriginWrench(wrongOrigin)), 0),
            (fixture.request(system, .hybrid(motion: task, wrench: wrench)), 1),
            (fixture.request(system, .constrainedContactForce(wrench)), 2),
            (fixture.request(system, .pointMotion(fixture.motion(axes: [.x, .x], acceleration: [4, 4], weights: [1, 1]))), 3),
            (fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [.infinity], weights: [1]))), 4),
            (fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [4], weights: [0]))), 4),
            (fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [4], weights: [1], secondary: [1, 2]))), 4)]
        for (request, kind) in requests {
            var work = try TaskSpaceQualificationFixture.work()
            try expect("Typed force/motion/domain/shape refusal", { failure in
                switch (kind, failure.cause) {
                case (0, .referencePointMismatch), (1, .incompatibleForceMotion), (2, .unsupportedDomain),
                     (3, .invalidInput), (4, .invalidShape): true
                default: false
                }
            }) { () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &work) }
        }
        let contact = try GeneralizedForceContribution(values: [0], channel: .contact)
        let contactSystem = try fixture.system(position: [0], velocity: [2], knownForces: [contact])
        var contactWork = try TaskSpaceQualificationFixture.work()
        try expect("Actually supplied contact channel is outside free-tree authority", { if case .unsupportedDomain = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(fixture.request(contactSystem, .pointMotion(task)), policy: policy, work: &contactWork)
        }
        let short = try fixture.policy(coordinateScales: [1, 1])
        var shapeWork = try TaskSpaceQualificationFixture.work()
        try expect("Actual original velocity layout/scales", { if case .invalidShape = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(fixture.request(system, .pointMotion(task)), policy: short, work: &shapeWork)
        }
    }

    private static func resourceFailure(_ failure: TaskSpaceFailure) -> Bool {
        switch failure.cause {
        case .numerical(.resourceLimit), .dynamics(.numerical(.resourceLimit, _)): true
        default: false
        }
    }
    public static func exactWorkAndCancellation() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0], velocity: [2]), policy = try fixture.policy()
        let request = fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [4], weights: [1])))
        let controller: any TaskSpaceControlling = ReferenceTaskSpaceController()
        var baseline = try TaskSpaceQualificationFixture.work(seeded: true)
        _ = try controller.evaluate(request, policy: policy, work: &baseline)
        var exact = try TaskSpaceQualificationFixture.work(operations: baseline.operations, storage: baseline.peakScalarStorage,
            iterations: baseline.iterations, seeded: true)
        let result = try controller.evaluate(request, policy: policy, work: &exact)
        try require(exact.operations == baseline.operations && exact.iterations == baseline.iterations &&
                    exact.peakScalarStorage == baseline.peakScalarStorage && result.diagnostics.work == exact,
                    "Exact actual cumulative work capacities admit the same physical command")
        for (operations, storage) in [(baseline.operations - 1, baseline.peakScalarStorage), (baseline.operations, baseline.peakScalarStorage - 1)] {
            var limited = try TaskSpaceQualificationFixture.work(operations: operations, storage: storage, iterations: baseline.iterations, seeded: true)
            try expect("One-less actual operation/storage bound", resourceFailure) {
                () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &limited)
            }
            try require(limited.operations >= 11 && limited.operations <= operations && limited.iterations <= baseline.iterations &&
                        limited.peakScalarStorage <= storage, "Resource refusal preserves the bounded consumed work prefix")
        }
        let cancelled = try fixture.policy(cancelled: true)
        var cancellationWork = try TaskSpaceQualificationFixture.work(seeded: true)
        try expect("Supplied cancellation", { if case .cancelled = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: cancelled, work: &cancellationWork)
        }
        try require(cancellationWork.operations == 11 && cancellationWork.iterations == 1 && cancellationWork.peakScalarStorage == 17,
                    "Pre-admission cancellation preserves caller seed without supplier work")
        let tooMany = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX), .prismatic(axis: .unitY)])
        let largeSystem = try tooMany.system(position: [0, 0], velocity: [0, 0]), capacity = try tooMany.policy(maximumVelocities: 1)
        var capacityWork = try TaskSpaceQualificationFixture.work()
        try expect("Caller velocity capacity", { if case .capacityExceeded = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(tooMany.request(largeSystem,
                .pointMotion(tooMany.motion(axes: [.x], acceleration: [1], weights: [1]))), policy: capacity, work: &capacityWork)
        }
        try require(capacityWork.operations == 0, "Capacity refusal precedes mass supplier execution")
    }

    public static func supplierFailureLedger() throws {
        let fixture = try TaskSpaceQualificationFixture(specifications: [.prismatic(axis: .unitX)])
        let system = try fixture.system(position: [0], velocity: [2]), policy = try fixture.policy()
        let request = fixture.request(system, .pointMotion(fixture.motion(axes: [.x], acceleration: [4], weights: [1])))
        var validOperations = 0, resetOperations = 0
        for reset in [false, true] {
            let controller: any TaskSpaceControlling = ReferenceTaskSpaceController(dynamics:
                TaskSpaceQualificationRefusingDynamics(mode: reset ? .resetThenRefuse : .chargeThenRefuse))
            var work = try TaskSpaceQualificationFixture.work(seeded: true)
            try expect("Original mass supplier failure ledger", { error in
                if reset { if case .invalidSupplierLedger = error.cause { return error.failedSupplierWorkUnavailable }; return false }
                if case .dynamics(.cancelled) = error.cause { return !error.failedSupplierWorkUnavailable }; return false
            }) { () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &work) }
            if reset { resetOperations = work.operations } else { validOperations = work.operations }
        }
        try require(validOperations == resetOperations + 13 && resetOperations > 11,
                    "Valid failed mass work is absorbed; replaced ledger retains only original known seed")
        let controller: any TaskSpaceControlling = ReferenceTaskSpaceController(linearSolver: TaskSpaceQualificationRefusingLinear())
        var linearWork = try TaskSpaceQualificationFixture.work(seeded: true)
        try expect("Original linear protocol exposes no failure work ledger", { error in
            if case .numerical(.cancelled) = error.cause { return error.failedSupplierWorkUnavailable }; return false
        }) { () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &linearWork) }
        try require(linearWork.operations > validOperations, "Linear failure occurs only after the actual original inverse-mass query")
    }

    public static func actualTaskCancellation(_ request: TaskSpaceRequest, policy: TaskSpacePolicy) throws {
        var work = try TaskSpaceQualificationFixture.work()
        let controller: any TaskSpaceControlling = ReferenceTaskSpaceController()
        try expect("Actual Task cancellation", { if case .cancelled = $0.cause { true } else { false } }) {
            () throws(TaskSpaceFailure) in _ = try controller.evaluate(request, policy: policy, work: &work)
        }
        try require(work.operations == 0, "Actual Task cancellation publishes no command or supplier work")
    }
}
