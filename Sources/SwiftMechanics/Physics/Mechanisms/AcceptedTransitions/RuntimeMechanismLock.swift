
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct RuntimeMechanismLock: MechanismLockEngaging {
    private let solver:any ConstrainedMechanismSolving
    public init(solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver()) { self.solver=solver }
    @inline(never)
    public func engage(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,model:CompiledMechanicalModel,
                       system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
                       equation:AffineMechanismEquation,continuation:IntegrationContinuationProvider,
                       work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,
                       linearWork:inout NumericalWork) throws(MechanismError) -> MechanismEngagement {
        guard session.snapshot() == expected,expected.physical.stamp == model.stamp,
              equation.descriptor == continuation.descriptor,equation.descriptor.model == model.stamp,
              system.input.snapshot.tree.layout == model.tree.layout,system.input.snapshot.tree.revision == model.stamp.revision,
              system.input.snapshot.time == expected.checkpoint.physical.time,system.input.velocity == expected.checkpoint.physical.v else { throw .staleBinding }
        let actual:KinematicSnapshot
        do throws(CompilationFailure) { actual=try model.evaluate(expected.physical) } catch { throw .compilation(error) }
        guard actual.bodies == system.input.snapshot.bodies else { throw .staleBinding }
        // Lock engagement is passive and stationary. Moving constraints require explicit actuator work.
        guard sample.drift.allSatisfy({$0 == 0}) else { throw .invalidInput }
        let impulse=try solver.reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
        guard let energy=impulse.kineticEnergyChange,energy <= policy.originalTolerance*policy.dynamics.energyScale else { throw .originalMomentum(residual:impulse.kineticEnergyChange ?? .infinity) }
        let n=system.velocityCount
        guard equation.descriptor.dimensions.count == 2*n else { throw .unsupportedChart }
        let trialReserved=try MechanismArithmetic.numerical { () throws(NumericalError) in
            let payload=try NumericalWork.sum(continuation.schema.maximumBytes,7)/8
            return try NumericalWork.sum(try NumericalWork.product(n,12),payload)
        }
        try MechanismArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(trialReserved) }
        var point=expected.checkpoint.physical.q;point.append(contentsOf:impulse.values)
        let captured=point
        let trialBudget=try MechanismArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:trialReserved) }
        let evidence=MechanismTrialLedger(NumericalWork(budget:trialBudget))
        var outcome:RuntimeTrialOutcome?,failure:RuntimeFailure?
        do throws(RuntimeFailure) {
            outcome=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                guard session.snapshot() == expected,trial.timeSeconds == expected.checkpoint.physical.time else { throw RuntimeFailure(.invalidOwnerAccess,message:"Lock source accepted time changed.") }
                for i in 0..<n {
                    guard try trial.position(at:i) == expected.checkpoint.physical.q[i],try trial.velocity(at:i) == expected.checkpoint.physical.v[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Lock source physical state changed.") }
                }
                var derivative=[Double](repeating:.nan,count:captured.count)
                var ledger=evidence.read()
                defer { evidence.store(ledger) }
                do { try ledger.chargeOperations(1) } catch { throw RuntimeFailure(.capacityExceeded,message:"Lock derivative ledger exhausted.") }
                let before=ledger
                var derivativeFailure:RuntimeFailure?
                do throws(RuntimeFailure) { try equation.derivative(time:trial.timeSeconds,point:captured,into:&derivative,work:&ledger,control:control) } catch { derivativeFailure=error }
                guard MechanismArithmetic.preserved(before,ledger) else { ledger=before;throw RuntimeFailure(.invalidOwnerAccess,message:"Lock derivative replaced authoritative work ledger.",failedSupplierWorkUnavailable:true) }
                if let derivativeFailure { throw derivativeFailure }
                try equation.write(point:captured,derivative:derivative,time:trial.timeSeconds,trial:&trial)
                var readback=[Double](repeating:.nan,count:captured.count);try equation.read(trial,into:&readback)
                guard readback == captured else { throw RuntimeFailure(.invalidState,message:"Lock chart publication altered reconciled physical state.") }
                let state:KinematicState
                do { state=try KinematicState(revision:model.stamp.revision,time:trial.timeSeconds,q:Array(captured[..<n]),v:Array(captured[n...]),acceleration:Array(derivative[n...])) }
                catch { throw RuntimeFailure(.invalidState,message:"Lock endpoint construction failed.") }
                try trial.replaceContributor(continuation.initialRecord(physical:state,equations:equation))
                return .accept
            }
            } catch { failure=error }
        try MechanismArithmetic.numerical { () throws(NumericalError) in try work.absorb(evidence.read(),reservedStorage:trialReserved) }
        if let failure { throw .runtime(failure) }
        guard let outcome else { throw .invalidShape }
        return MechanismEngagement(accepted:outcome.accepted,impulse:impulse)
    }
}
