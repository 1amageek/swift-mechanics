import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

extension FoundationVerification {
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    static func verifyPlanarEvolution() throws {
        let fixture = try FourBarProbeModel(planar: true)
        let equation = try GeometricEvolutionProbeContext.equation(fixture, physical: true)
        let (session, provider) = try PlanarEvolutionProbeContext.session(fixture, equation: equation)
        defer { _ = session.shutdown() }
        print("AF24 planar public phase: initial original physical proof")
        try checkPlanarEvolutionProof(session, fixture: fixture, equation: equation)
        print("AF24 planar public phase: original evolution and saved prefix")
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        _ = try service.advance(session, equations: equation, continuation: provider, to: 0.1)
        let codec = NativeRuntimeCheckpointCodec(), saved = try session.checkpoint(codec: codec)
        print("AF24 planar public phase: forged tangent cold refusal")
        try checkPlanarColdForgery(session, fixture: fixture)
        let final = try service.advance(session, equations: equation, continuation: provider, to: 0.2).accepted
        try checkPlanarEvolutionState(fixture, state: final.checkpoint.physical)
        try checkPlanarEvolutionProof(session, fixture: fixture, equation: equation)
        let finalBytes = try session.checkpoint(codec: codec)
        _ = try session.restart(saved, codec: codec)
        try require(try service.advance(session, equations: equation, continuation: provider, to: 0.2).accepted == final)
        try require(try session.checkpoint(codec: codec) == finalBytes)
        print("AF24 planar public phase: fresh exact replay")
        try checkPlanarFreshReplay(saved, final: final, finalBytes: finalBytes)
        print("AF24 planar public phase: changed inertia cold refusal")
        try checkPlanarChangedInertia(saved)
        print("AF24 planar public phase: independent refinement")
        try checkPlanarRefinement()
        print("AF24 planar evolution: original 2D inertia/q/v/a/force/energy, refinement, cold exact replay and forgery refusal passed")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarEvolutionState(_ fixture: FourBarProbeModel, state: KinematicState) throws {
        for value in fixture.originalClosure(q: state.q) { try require(abs(value) < 3e-9) }
        for value in fixture.originalVelocity(q: state.q, v: state.v) { try require(abs(value) < 3e-8) }
        for value in fixture.originalAcceleration(q: state.q, v: state.v, acceleration: state.acceleration) { try require(abs(value) < 3e-8) }
        try require(abs(fixture.originalKineticEnergy(q: state.q, v: state.v)-(state.q[fixture.crankIndex]-0.5)) < 2e-8)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarEvolutionProof(_ session: PlanarEvolutionProbeContext.Session, fixture: FourBarProbeModel,
                                                 equation: GeometricMechanismEquation) throws {
        let prefix = session.snapshot()
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            var work = NumericalWork(budget: equation.publicationBudget)
            var point = [Double](repeating: 0, count: 6)
            try equation.read(trial, into: &point)
            let proof = try equation.consistent(time: trial.timeSeconds, point: point, work: &work, control: control)
            let q = Array(point[0..<3]), v = Array(point[3..<6]), force = fixture.originalInertiaForce(q: q, v: v, acceleration: proof.acceleration.values)
            guard let energy = proof.mechanicalEnergy, proof.acceleration.rank.rank == 2,
                  proof.acceleration.rank.reactionNullity == 1, proof.acceleration.rowIDs == [1, 2, 3],
                  proof.acceleration.rowMultipliers[2] == 0,
                  abs(energy.kineticEnergy-fixture.originalKineticEnergy(q: q, v: v)) < 1e-10,
                  abs(energy.requiredVirtualPower-v[fixture.crankIndex]) < 1e-8, energy.requiredPrescribedPower == 0 else {
                throw RuntimeFailure(.invalidState, message: "Planar original rank, kinetic energy or virtual power differs.")
            }
            for i in force.indices {
                guard abs(force[i]-equation.drive[i]-proof.acceleration.generalizedReaction[i]) < 1e-8 else {
                    throw RuntimeFailure(.invalidState, message: "Planar original Euler-Lagrange force differs.")
                }
            }
            if trial.timeSeconds == 0 {
                let a = q[fixture.crankIndex], b = a+q[fixture.couplerIndex], c = q[fixture.rockerIndex]
                var tangent = [Double](repeating: 0, count: 3)
                tangent[fixture.crankIndex] = 1
                let absoluteCoupler = 0.5*sin(c-a)/sin(b-c), rocker = 0.5*sin(b-a)/sin(b-c)
                tangent[fixture.couplerIndex] = absoluteCoupler-1; tangent[fixture.rockerIndex] = rocker
                let mass = 2*fixture.originalKineticEnergy(q: q, v: tangent)
                for i in tangent.indices {
                    guard abs(proof.acceleration.values[i]-tangent[i]/mass) < 1e-9 else {
                        throw RuntimeFailure(.invalidState, message: "Planar independent initial effective inertia differs.")
                    }
                }
            }
            _ = try trial.nextRandom()
            return .reject
        }
        try require(session.snapshot() == prefix)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarFreshReplay(_ saved: [UInt8], final: RuntimeAcceptedState, finalBytes: [UInt8]) throws {
        let fixture = try FourBarProbeModel(planar: true), equation = try GeometricEvolutionProbeContext.equation(fixture, physical: true)
        let (session, provider) = try PlanarEvolutionProbeContext.session(fixture, equation: equation)
        defer { _ = session.shutdown() }
        let codec = NativeRuntimeCheckpointCodec()
        _ = try session.restart(saved, codec: codec)
        let service: any ProjectedMechanismEvolving = ProjectedNonlinearMechanismEvolution()
        try require(try service.advance(session, equations: equation, continuation: provider, to: 0.2).accepted == final)
        try require(try session.checkpoint(codec: codec) == finalBytes)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarChangedInertia(_ saved: [UInt8]) throws {
        let fixture = try FourBarProbeModel(planar: true, polarScale: 1.2), equation = try GeometricEvolutionProbeContext.equation(fixture, physical: true)
        let (session, _) = try PlanarEvolutionProbeContext.session(fixture, equation: equation)
        defer { _ = session.shutdown() }
        let prefix = session.snapshot(); var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(saved, codec: NativeRuntimeCheckpointCodec()) }
        catch {
            print("AF24 changed-inertia original force refusal: " + error.message)
            try require(error.code == .invalidState); refused = true
        }
        try require(refused && session.snapshot() == prefix)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarColdForgery(_ session: PlanarEvolutionProbeContext.Session, fixture: FourBarProbeModel) throws {
        let prefix = session.snapshot(), old = prefix.checkpoint, s = old.physical, codec = NativeRuntimeCheckpointCodec()
        let saved = try session.checkpoint(codec: codec), a = s.q[fixture.crankIndex], b = a+s.q[fixture.couplerIndex], c = s.q[fixture.rockerIndex]
        var acceleration = s.acceleration
        acceleration[fixture.crankIndex] += 0.2
        acceleration[fixture.couplerIndex] += 0.2*(0.5*sin(c-a)/sin(b-c)-1)
        acceleration[fixture.rockerIndex] += 0.1*sin(b-a)/sin(b-c)
        for residual in fixture.originalAcceleration(q: s.q, v: s.v, acceleration: acceleration) { try require(abs(residual) < 3e-8) }
        let candidate = try KinematicState(revision: s.revision, time: s.time, q: s.q, v: s.v, acceleration: acceleration)
        let checkpoint = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: candidate,
            contributors: old.contributors, random: old.random, acceptedSteps: old.acceptedSteps)
        let encoded = try codec.encode(checkpoint, capacity: session.configuration.capacity)
        var refused = false
        do throws(RuntimeFailure) { _ = try session.restart(encoded, codec: codec) }
        catch { try require(error.code == .invalidState); refused = true }
        try require(refused && session.snapshot() == prefix && (try session.checkpoint(codec: codec)) == saved)
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @inline(never)
    private static func checkPlanarRefinement() throws {
        let fixture = try FourBarProbeModel(planar: true), equation = try GeometricEvolutionProbeContext.equation(fixture, physical: true)
        var states: [[Double]] = []
        for step in [0.1, 0.05, 0.025] {
            let (session, provider) = try PlanarEvolutionProbeContext.session(fixture, equation: equation, step: step)
            defer { _ = session.shutdown() }
            let result = try ProjectedNonlinearMechanismEvolution().advance(session, equations: equation, continuation: provider, to: 0.6)
            let state = result.accepted.checkpoint.physical
            for residual in fixture.originalAcceleration(q: state.q, v: state.v, acceleration: state.acceleration) { try require(abs(residual) < 3e-8) }
            try require(abs(fixture.originalKineticEnergy(q: state.q, v: state.v)-(state.q[fixture.crankIndex]-0.5)) < 1e-5)
            states.append(state.q+state.v)
        }
        var coarse = 0.0, fine = 0.0
        for i in states[0].indices {
            coarse += (states[0][i]-states[1][i])*(states[0][i]-states[1][i])
            fine += (states[1][i]-states[2][i])*(states[1][i]-states[2][i])
        }
        try require(coarse > 50*fine)
    }
}
