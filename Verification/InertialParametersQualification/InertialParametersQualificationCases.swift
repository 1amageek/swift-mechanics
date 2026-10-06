import SwiftMechanics

public enum InertialParametersQualificationCases {
    private typealias F = InertialParametersQualificationFixture
    private typealias O = InertialParametersQualificationOracle

    public static func tenCoordinateOriginLaws() throws {
        let fixture = try F(), binding = fixture.input.bindings[1]
        try O.close(binding.firstMoment.x, 0.8, "Literal first moment x kg m")
        try O.close(binding.firstMoment.y, -0.4, "Literal first moment y kg m")
        try O.close(binding.firstMoment.z, 0.2, "Literal first moment z kg m")
        try O.close(binding.inertiaAtOrigin.m00, 2.5, "Literal origin tensor xx kg m2")
        try O.close(binding.inertiaAtOrigin.m11, 3.54, "Literal origin tensor yy kg m2")
        try O.close(binding.inertiaAtOrigin.m22, 4, "Literal origin tensor zz kg m2")
        try O.close(binding.inertiaAtOrigin.m01, 0.36, "Literal origin tensor xy")
        try O.close(binding.inertiaAtOrigin.m02, -0.18, "Literal origin tensor xz")
        try O.close(binding.inertiaAtOrigin.m12, 0.19, "Literal origin tensor yz")
        for coordinate in 0..<10 {
            let result = try fixture.product(fixture.direction(coordinate: coordinate))
            let dz = coordinate == 6 ? 1.0 : 0.0
            try O.array(result.mechanics.massMatrix, [dz], "Literal ten-coordinate mass \(coordinate)")
            try O.array(result.mechanics.inertialBias, [0], "Literal ten-coordinate bias \(coordinate)")
            try O.array(result.mechanics.totalForce, [0], "Literal absent force \(coordinate)")
            try O.array(result.requiredDriveDirection, [3*dz], "Literal required torque \(coordinate)")
            try O.close(result.mechanics.kineticEnergy, 2*dz, "Literal kinetic derivative \(coordinate)")
            try O.close(result.primalEnergy.kineticEnergy, 8, "Original primal kinetic")
            try O.array(result.primalInverse.driveForce, [12], "Original primal inverse torque")
            try O.require(result.originalResidual <= result.originalThreshold && result.primalInverse.originalPhysicalResidual.isAccepted,
                "Literal original equation acceptance")
        }
        let combination = try fixture.product(fixture.direction(combined: true))
        try O.array(combination.requiredDriveDirection, [1.2], "Signed combined origin law")
        let root = try fixture.product(fixture.direction(body: 0, combined: true))
        try O.array(root.requiredDriveDirection, [0], "Static root inertia has no generalized effect")
        try O.close(root.mechanics.kineticEnergy, 0, "Static root kinetic direction")
    }

    public static func uniformGravityAndPower() throws {
        let fixture = try F(gravity: true, applied: true), result = try fixture.product(fixture.direction(combined: true))
        try O.array(result.mechanics.totalForce, [2], "Literal gravity first-moment force")
        try O.close(result.mechanics.gravityPotential, 1, "Literal gravity first-moment potential")
        try O.close(result.mechanics.actualLoadPower, 4, "Literal gravity actual power derivative")
        try O.close(result.mechanics.virtualLoadPower, 4, "Literal gravity virtual power derivative")
        try O.close(result.mechanics.prescribedLoadPower, 0, "Literal prescribed power derivative")
        try O.array(result.requiredDriveDirection, [-0.8], "Literal loaded required torque derivative")
        try O.array(result.primalInverse.driveForce, [15], "Original loaded inverse torque")
        let primal = try O.primal(fixture.input.primal, fixture: fixture)
        try O.close(primal.system.forces.actualPower, -6, "Gravity plus fixed applied load power")
        try O.close(primal.energy.kineticEnergyRate, 24, "Original kinetic rate")
        try O.close(primal.inverse.driveForce[0]*2 + primal.system.forces.actualPower, primal.energy.kineticEnergyRate,
            "Actual drive and load energy balance")
        try O.close(primal.system.gravityPotential, -4, "Literal potential at offset COM")
        try O.differences(fixture, direction: fixture.direction(combined: true))
    }

    public static func rotatedCoupledDifferences() throws {
        let fixture = try F(coupled: true, gravity: true, applied: true)
        for coordinate in 0..<10 { try O.differences(fixture, direction: fixture.direction(coordinate: coordinate)) }
        try O.differences(fixture, direction: fixture.direction(body: 2, combined: true))
        try O.differences(fixture, direction: fixture.direction(body: 0, combined: true))
        let primal = try O.primal(fixture.input.primal, fixture: fixture)
        try O.require(abs(primal.system.massMatrix[1]) > 1e-4, "Nonidentity coupled mass witness")
        try O.require(primal.system.inertialBias.contains { abs($0) > 1e-4 }, "Moving coupled bias witness")
    }

    public static func forwardAccelerationAndRoundtrip() throws {
        let fixture = try F(gravity: true, applied: true), direction = try fixture.direction(combined: true)
        let result = try fixture.forward(direction)
        // M=4, total force=-3, fixed drive=7, dM=.4 and dQ=2.
        try O.array(result.dynamics.primal.acceleration, [1], "Literal primal forward acceleration")
        try O.array(result.dynamics.acceleration, [0.4], "Literal implicit acceleration derivative")
        try O.require(result.dynamics.originalResidual <= result.dynamics.originalThreshold &&
            result.dynamics.primal.originalPhysicalResidual.isAccepted, "Original forward acceptance")
        try O.differences(fixture, direction: direction, forward: true)
        let coupled = try F(coupled: true, gravity: true, applied: true)
        try O.differences(coupled, direction: coupled.direction(combined: true), forward: true)
        let primal = try O.primal(coupled.input.primal, fixture: coupled)
        let solver: any RigidDynamicsSolving = DenseRigidDynamics()
        var work = try F.work()
        let roundtrip = try solver.forward(primal.system, driveForce: primal.inverse.driveForce, policy: coupled.solvePolicy, work: &work)
        try O.array(roundtrip.acceleration, coupled.input.primal.state.acceleration, "Original inverse/forward roundtrip")
        try O.require(roundtrip.originalPhysicalResidual.isAccepted, "Roundtrip original residual")
    }

    public static func sourceAndMappingRefusals() throws {
        let fixture = try F(), direction = try fixture.direction(combined: true)
        let p = fixture.input.primal
        let staleState = try KinematicState(revision: 8, time: p.state.time, q: p.state.q, v: p.state.v, acceleration: p.state.acceleration)
        try refuse(fixture, input: fixture.replacing(primal: fixture.primal(state: staleState)), direction: direction, label: "State revision") {
            if case .staleMapping = $0 { return true }; return false
        }
        var representations = fixture.input.currentRepresentations
        representations[1] = try InertialRepresentation3D(properties: representations[1].properties,
            provenance: SourceProvenance(source: representations[1].provenance.source, revision: 5), quality: .exact)
        try refuse(fixture, input: fixture.replacing(representations: representations), direction: direction, label: "Current physical provenance") {
            if case .staleMapping = $0 { return true }; return false
        }
        let record = fixture.records[1]
        let wrongFrame = try BodyRecord3D(id: record.id, frame: F.id(.frame, "foreign"), mode: record.mode,
            bodyToWorld: record.bodyToWorld, representations: record.representations, inertia: record.inertia)
        var bindings = fixture.input.bindings
        bindings[1] = try RigidInertialParameterBinding(body: wrongFrame, modelRevision: 7, parameterIDs: bindings[1].parameterIDs)
        try refuse(fixture, input: fixture.replacing(bindings: bindings), direction: direction, label: "Frame identity") {
            if case .staleMapping = $0 { return true }; return false
        }
        bindings = fixture.input.bindings
        bindings[1] = try RigidInertialParameterBinding(body: record, modelRevision: 8, parameterIDs: bindings[1].parameterIDs)
        try refuse(fixture, input: fixture.replacing(bindings: bindings), direction: direction, label: "Binding revision") {
            if case .staleMapping = $0 { return true }; return false
        }
        bindings = fixture.input.bindings
        bindings[1] = try RigidInertialParameterBinding(body: record, modelRevision: 7, parameterIDs: bindings[0].parameterIDs)
        var duplicateDirection = direction
        duplicateDirection[1] = try RigidInertialParameterDirection(binding: bindings[1])
        try refuse(fixture, input: fixture.replacing(bindings: bindings), direction: duplicateDirection, label: "Cross-body duplicate IDs") {
            if case .invalidInput = $0 { return true }; return false
        }
        try refuse(fixture, input: fixture.input, direction: [], label: "Direction shape") {
            if case .invalidShape = $0 { return true }; return false
        }
        try refuse(fixture, input: fixture.replacing(topology: false), direction: direction, label: "Topology change") {
            if case .topologyChange = $0 { return true }; return false
        }
        try refuse(fixture, input: fixture.replacing(independent: false), direction: direction, label: "Absent force derivative assumption") {
            if case .forceDerivativeUnavailable = $0 { return true }; return false
        }
        var reversed = fixture.input.currentRepresentations; reversed.swapAt(0, 1)
        try refuse(fixture, input: fixture.replacing(representations: reversed), direction: direction, label: "Occurrence order") {
            if case .staleMapping = $0 { return true }; return false
        }
    }

    public static func physicalAndRankDomains() throws {
        let fixture = try F(), direction = try fixture.direction(combined: true)
        var negative = direction
        negative[1] = try RigidInertialParameterDirection(binding: fixture.input.bindings[1], mass: 3000)
        try refuse(fixture, input: fixture.input, direction: negative, label: "Nonphysical mass endpoint") {
            if case .model(.invalidMass) = $0 { return true }; return false
        }
        try refuse(fixture, input: fixture.input, direction: direction, policy: F.policy(physicality: 1e-10), label: "Physicality tolerance") {
            if case .unsupportedDomain = $0 { return true }; return false
        }
        let gradient = try AffineGravity(frame: fixture.input.primal.tree.worldFrame, accelerationAtOrigin: .zero, gradient: .identity)
        try refuse(fixture, input: fixture.replacing(primal: fixture.primal(gravity: gradient, replaceGravity: true)), direction: direction, label: "Distributed gravity unsupported") {
            if case .unsupportedDomain = $0 { return true }; return false
        }
        let foreign = try AffineGravity(frame: F.id(.frame, "foreign-gravity"), accelerationAtOrigin: .unitX)
        try refuse(fixture, input: fixture.replacing(primal: fixture.primal(gravity: foreign, replaceGravity: true)), direction: direction, label: "Gravity frame") {
            if case .unsupportedDomain = $0 { return true }; return false
        }
        var work = try F.work(seeded: true), loads = try F.loads(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        do {
            _ = try supplier.forwardProduct(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
                admission: fixture.admission, solvePolicy: F.solve(count: 1, pivot: 10), policy: F.policy(),
                loadWork: &loads, supplierWork: &calls, work: &work)
            throw InertialParametersQualificationError.unexpectedSuccess("Original scaled-mass pivot refusal")
        } catch let error as InertialParameterError {
            guard case .derivative(.dynamics(.numerical(.nonPositiveDefinite, _), _)) = error else {
                throw InertialParametersQualificationError.unexpectedFailure(error)
            }
        }
        try O.require(work.operations > 11 && calls.calls > 4 && loads.consumed >= 5, "Failed actual forward supplier work retained")
    }

    public static func cumulativeWorkBounds() throws {
        let fixture = try F(coupled: true, gravity: true, applied: true), direction = try fixture.direction(combined: true)
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        var work = try F.work(seeded: true), loads = try F.loads(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
        try calls.chargeCall()
        let reference = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
            admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: F.policy(),
            loadWork: &loads, supplierWork: &calls, work: &work)
        var exact = try F.work(operations: work.operations, storage: work.peakScalarStorage, iterations: work.iterations, seeded: true)
        var exactLoads = try F.loads(seeded: true), exactCalls = try DerivativeSupplierWork(maximumCalls: calls.calls)
        try exactCalls.chargeCall()
        let replay = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
            admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: F.policy(),
            loadWork: &exactLoads, supplierWork: &exactCalls, work: &exact)
        try O.array(replay.requiredDriveDirection, reference.requiredDriveDirection, "Exact budget replay")
        try O.require(exact.operations == work.operations && exact.peakScalarStorage == work.peakScalarStorage &&
            exact.iterations == work.iterations && exactCalls.calls == calls.calls && exactLoads.consumed == loads.consumed,
            "Cumulative exact ledgers")
        for short in 0..<3 {
            var bounded = try F.work(operations: work.operations-(short == 0 ? 1 : 0),
                storage: work.peakScalarStorage-(short == 1 ? 1 : 0), iterations: work.iterations, seeded: true)
            var boundedLoads = try F.loads(seeded: true)
            var boundedCalls = try DerivativeSupplierWork(maximumCalls: calls.calls-(short == 2 ? 1 : 0))
            try boundedCalls.chargeCall()
            do {
                _ = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
                    admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: F.policy(),
                    loadWork: &boundedLoads, supplierWork: &boundedCalls, work: &bounded)
                throw InertialParametersQualificationError.unexpectedSuccess("One-short bound \(short)")
            } catch let error as InertialParameterError {
                if short == 2 {
                    guard case .derivative(.capacityExceeded) = error else { throw InertialParametersQualificationError.unexpectedFailure(error) }
                } else { try O.require(isResource(error), "Typed exhausted numerical bound") }
            }
            try O.require(bounded.operations >= 11 && bounded.peakScalarStorage >= 17 && bounded.iterations >= 1 &&
                boundedCalls.calls >= 1 && boundedLoads.consumed >= 5, "One-short failure retains owned prefix")
        }
    }

    public static func callerAndPublicationCancellation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw InertialParametersQualificationError.unsupportedPlatform("Final publication cancellation requires the declared Mutex platform availability")
        }
        let fixture = try F(), direction = try fixture.direction(combined: true)
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        for admissionCancellation in [false, true] {
            var work = try F.work(seeded: true), loads = try F.loads(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
            let previous = work
            let admission = DynamicsAdmission(capacity: fixture.admission.capacity,
                angularVelocityTolerance: fixture.admission.angularVelocityTolerance,
                linearVelocityTolerance: fixture.admission.linearVelocityTolerance, isCancelled: { admissionCancellation })
            do {
                _ = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
                    admission: admission, solvePolicy: fixture.solvePolicy,
                    policy: F.policy(cancelled: { !admissionCancellation }), loadWork: &loads, supplierWork: &calls, work: &work)
                throw InertialParametersQualificationError.unexpectedSuccess("Initial policy/admission cancellation")
            } catch let error as InertialParameterError {
                guard case .cancelled = error else { throw InertialParametersQualificationError.unexpectedFailure(error) }
            }
            try O.require(work == previous && calls.calls == 0 && loads.consumed == 5 && loads.peakScalars == 7,
                "Initial cancellation unchanged ledgers")
        }
        try finalPollCancellation(fixture, direction: direction)
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func finalPollCancellation(_ fixture: F, direction: [RigidInertialParameterDirection]) throws {
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        let referenceCounter = InertialParametersQualificationCancellation(cancelAt: Int.max)
        var work = try F.work(), loads = try F.loads(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        _ = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
            admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: F.policy(cancelled: { referenceCounter.poll() }),
            loadWork: &loads, supplierWork: &calls, work: &work)
        let counter = InertialParametersQualificationCancellation(cancelAt: referenceCounter.count)
        var cancelledWork = try F.work(), cancelledLoads = try F.loads(), cancelledCalls = try DerivativeSupplierWork(maximumCalls: 100)
        do {
            _ = try supplier.product(fixture.input, direction: direction, jointPolicy: fixture.jointPolicy,
                admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: F.policy(cancelled: { counter.poll() }),
                loadWork: &cancelledLoads, supplierWork: &cancelledCalls, work: &cancelledWork)
            throw InertialParametersQualificationError.unexpectedSuccess("Final publication cancellation")
        } catch let error as InertialParameterError {
            guard case .cancelled = error else { throw InertialParametersQualificationError.unexpectedFailure(error) }
        }
        try O.require(counter.count == referenceCounter.count && cancelledWork == work && cancelledCalls.calls == calls.calls &&
            cancelledLoads.consumed == loads.consumed, "Final cancellation retains every completed call/work unit")
    }

    public static func actualTaskCancellation(_ input: InertialParameterInput, direction: [RigidInertialParameterDirection],
        fixture: InertialParametersQualificationFixture, policy: DerivativePolicy, work: inout NumericalWork, loads: inout LoadWork,
        calls: inout DerivativeSupplierWork) throws {
        let previous = work, previousLoads = loads.consumed, previousCalls = calls.calls
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        do {
            _ = try supplier.product(input, direction: direction, jointPolicy: fixture.jointPolicy, admission: fixture.admission,
                solvePolicy: fixture.solvePolicy, policy: policy, loadWork: &loads, supplierWork: &calls, work: &work)
            throw InertialParametersQualificationError.unexpectedSuccess("Actual cancelled Task")
        } catch let error as InertialParameterError {
            guard case .cancelled = error else { throw InertialParametersQualificationError.unexpectedFailure(error) }
        }
        try O.require(work == previous && loads.consumed == previousLoads && calls.calls == previousCalls, "Cancelled Task unchanged prefix")
    }

    private static func refuse(_ fixture: F, input: InertialParameterInput, direction: [RigidInertialParameterDirection],
        policy: DerivativePolicy? = nil, label: String, matches: (InertialParameterError) -> Bool) throws {
        var work = try F.work(seeded: true), loads = try F.loads(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let selected: DerivativePolicy
        if let policy { selected = policy } else { selected = try F.policy() }
        let supplier: any InertialParameterDifferentiating = ExactInertialParameterDifferentiator()
        do {
            _ = try supplier.product(input, direction: direction, jointPolicy: fixture.jointPolicy,
                admission: fixture.admission, solvePolicy: fixture.solvePolicy, policy: selected,
                loadWork: &loads, supplierWork: &calls, work: &work)
            throw InertialParametersQualificationError.unexpectedSuccess(label)
        } catch let error as InertialParameterError {
            try O.require(matches(error), label + " exact typed refusal")
        }
        try O.require(work.operations >= 11 && work.peakScalarStorage >= 17 && work.iterations >= 1 && loads.consumed >= 5,
            label + " unchanged or retained prefix")
    }
    private static func isResource(_ error: InertialParameterError) -> Bool {
        switch error {
        case .numerical(.resourceLimit), .derivative(.numerical(.resourceLimit)),
             .dynamics(.numerical(.resourceLimit, _)), .derivative(.dynamics(.numerical(.resourceLimit, _), _)): return true
        default: return false
        }
    }
}
