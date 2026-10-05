public struct ReferenceStationaryIslandDynamics: StationaryIslandComputing {
    private let equations: any RigidEquationComputing
    private let dynamics: any RigidDynamicsSolving
    private let evaluator: any ConstraintEvaluating
    private let solver: any ConstrainedMechanismSolving
    public init(equations: any RigidEquationComputing = RigidEquationKernel(), dynamics: any RigidDynamicsSolving = DenseRigidDynamics(),
                evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator(), solver: any ConstrainedMechanismSolving = MassWeightedMechanismSolver()) {
        self.equations=equations;self.dynamics=dynamics;self.evaluator=evaluator;self.solver=solver
    }
    @inline(never)
    public func motion(program: StationaryIslandProgram,islandID: UInt64,physical: KinematicState,
                       work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandMotion {
        do throws(StationaryIslandFailureReason) { return try actualMotion(program:program,islandID:islandID,physical:physical,work:&work) }
        catch { if IslandArithmetic.unavailable(error) { work.unavailable() };throw StationaryIslandFailure(error,work:work) }
    }
    @inline(never)
    public func certifyRest(program: StationaryIslandProgram,islandID: UInt64,physical: KinematicState,
                            thresholds: MechanismSleepPolicy,work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandRestCertificate? {
        do throws(StationaryIslandFailureReason) {
            guard !thresholds.isCancelled() else { throw .cancelled }
            guard thresholds.maximumCoordinates >= program.source.tree.layout.velocityCount else { throw .capacityExceeded }
            try IslandSource.validatePartition(program,physical:physical,equations:equations,work:&work)
            let motion=try actualMotion(program:program,islandID:islandID,physical:physical,work:&work)
            try positiveMass(motion.system.massMatrix,n:motion.acceleration.count,reserved:try IslandArithmetic.sum(IslandSource.reserved(program),motion.system.scalarStorage),work:&work.numerical)
            var speed=0.0
            for i in motion.island.sourceCoordinateIndices {
                try IslandArithmetic.charge(3,&work.numerical)
                speed=max(speed,abs(physical.v[i]*program.constraints.layout.timeScale/program.constraints.layout.scales[i]))
            }
            guard speed <= thresholds.normalizedVelocityThreshold,motion.kineticEnergy <= thresholds.kineticEnergyThreshold,
                  motion.island.sourceCoordinateIndices.allSatisfy({physical.v[$0] == 0}),motion.acceleration.allSatisfy({$0 == 0}) else { return nil }
            try IslandArithmetic.check(program.policy)
            return StationaryIslandRestCertificate(motion:motion,speed:speed)
        } catch { if IslandArithmetic.unavailable(error) { work.unavailable() };throw StationaryIslandFailure(error,work:work) }
    }
    public func associateRest(certificate: StationaryIslandRestCertificate,program: StationaryIslandProgram,
                              physical: KinematicState,work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> Bool {
        do throws(StationaryIslandFailureReason) {
            try IslandArithmetic.check(program.policy)
            let n=program.source.tree.layout.velocityCount
            guard physical.revision == program.source.stamp.revision,physical.q.count == n,physical.v.count == n,
                  physical.acceleration.count == n,physical.prescribedAnchors.isEmpty,
                  physical.q.allSatisfy({$0.isFinite}),physical.v.allSatisfy({$0.isFinite}),physical.acceleration.allSatisfy({$0.isFinite}) else { throw .sourceMismatch }
            try IslandArithmetic.storage(try IslandSource.reserved(program),&work.numerical)
            try IslandArithmetic.charge(try IslandArithmetic.sum(program.binding.count,try IslandArithmetic.product(3,n)),&work.numerical)
            guard certificate.program.binding == program.binding,physical.time >= program.constraints.minimumTime,
                  physical.time <= program.constraints.maximumTime else { return false }
            try IslandSource.admit(program,physical,work:&work.numerical)
            guard let island=program.islands.first(where:{$0.id == certificate.islandID}),
                  certificate.position.count == island.sourceCoordinateIndices.count else { throw .sourceMismatch }
            for i in island.sourceCoordinateIndices.indices {
                try IslandArithmetic.charge(2,&work.numerical)
                guard physical.q[island.sourceCoordinateIndices[i]].bitPattern == certificate.position[i].bitPattern,
                      physical.v[island.sourceCoordinateIndices[i]] == 0 else { return false }
            };return true
        } catch { if IslandArithmetic.unavailable(error) { work.unavailable() };throw StationaryIslandFailure(error,work:work) }
    }
    @inline(never)
    private func actualMotion(program: StationaryIslandProgram,islandID: UInt64,physical: KinematicState,
                              work: inout StationaryIslandWork) throws(StationaryIslandFailureReason) -> StationaryIslandMotion {
        try IslandSource.admit(program,physical,work:&work.numerical)
        guard let island=program.islands.first(where:{$0.id == islandID}) else { throw .sourceMismatch }
        let reserved=try IslandSource.reserved(program)
        let state=try IslandSource.physical(physical,island:island)
        let system=try IslandSource.assemble(IslandSource.input(model:island.model,physical:state,inertias:island.inertias),
            program:program,equations:equations,reserved:reserved,work:&work)
        let live=try IslandArithmetic.sum(reserved,system.scalarStorage)
        let acceleration:[Double],reaction:[Double],constrained:ConstrainedMotion?
        if let constraints=island.constraints {
            let sample=try rows(constraints:constraints,island:island,state:state,reserved:live,work:&work.numerical)
            let result=try constrainedMotion(system:system,sample:sample,island:island,reserved:live,work:&work.numerical)
            acceleration=result.values;reaction=result.generalizedReaction;constrained=result
        } else {
            let result=try IslandInvocation.local(work:&work.numerical,reserved:live) { (local:inout NumericalWork) throws(StationaryIslandFailureReason) in
                do throws(DynamicsError) { return try dynamics.forward(system,driveForce:island.drive,policy:island.policy.dynamics,work:&local) }
                catch { throw .dynamics(error) }
            };acceleration=result.acceleration;reaction=[Double](repeating:0,count:state.v.count);constrained=nil
        }
        let energy=try accept(system:system,island:island,state:state,acceleration:acceleration,reaction:reaction,reserved:live,work:&work.numerical)
        try IslandArithmetic.check(program.policy)
        return StationaryIslandMotion(program:program,island:island,physical:physical,system:system,acceleration:acceleration,reaction:reaction,energy:energy,constrained:constrained)
    }
    @inline(never)
    private func rows(constraints: QuadraticConstraintSystem,island: StationaryMechanicalIsland,state: KinematicState,
                      reserved: Int,work: inout NumericalWork) throws(StationaryIslandFailureReason) -> VelocityConstraintSample {
        let evaluation=try IslandInvocation.local(work:&work,reserved:reserved) { (local:inout NumericalWork) throws(StationaryIslandFailureReason) in
            do throws(ConstraintError) { return try evaluator.evaluate(constraints,position:state.q,velocity:state.v,time:state.time,policy:island.policy.constraints.evaluation,work:&local) }
            catch { throw .constraint(error) }
        }
        let n=state.q.count,m=constraints.rows.count
        guard evaluation.rowIDs == island.retainedRowIDs,evaluation.layoutRevision == state.revision,evaluation.jacobian.count == n*m,
              evaluation.values.count == m,evaluation.timeDerivative.count == m,evaluation.accelerationBias.count == m,
              evaluation.normalizedPosition.count == n,evaluation.normalizedVelocity.count == n else { throw .sourceMismatch }
        for r in 0..<m {
            var q=constraints.rows[r].constant,v=0.0
            for i in 0..<n {
                try IslandArithmetic.charge(8,&work)
                guard evaluation.jacobian[r*n+i] == constraints.rows[r].linear[i],
                      evaluation.normalizedPosition[i] == state.q[i]/constraints.layout.scales[i],
                      evaluation.normalizedVelocity[i] == state.v[i]*constraints.layout.timeScale/constraints.layout.scales[i] else { throw .sourceMismatch }
                q += constraints.rows[r].linear[i]*evaluation.normalizedPosition[i]
                v += constraints.rows[r].linear[i]*evaluation.normalizedVelocity[i]
            }
            guard q.isFinite,v.isFinite,evaluation.values[r] == q,evaluation.timeDerivative[r] == 0,evaluation.accelerationBias[r] == 0,
                  abs(q) <= island.policy.originalTolerance,abs(v) <= island.policy.originalTolerance else { throw .residualRejected }
        }
        return VelocityConstraintSample(layout:constraints.layout,holonomic:evaluation)
    }
    @inline(never)
    private func constrainedMotion(system: RigidDynamicsSystem,sample: VelocityConstraintSample,island: StationaryMechanicalIsland,
                                   reserved: Int,work: inout NumericalWork) throws(StationaryIslandFailureReason) -> ConstrainedMotion {
        let remaining=try IslandArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let budget=try IslandArithmetic.numerical { () throws(NumericalError) in
            try NumericalBudget(scalarStorage:remaining.scalarStorage/4,arithmeticOperations:remaining.arithmeticOperations/4,iterations:remaining.iterations/4)
        }
        var outer=NumericalWork(budget:budget),dynamics=NumericalWork(budget:budget),rank=NumericalWork(budget:budget),linear=NumericalWork(budget:budget)
        for i in 0..<4 { switch i { case 0:try IslandArithmetic.charge(1,&outer);case 1:try IslandArithmetic.charge(1,&dynamics);case 2:try IslandArithmetic.charge(1,&rank);default:try IslandArithmetic.charge(1,&linear) } }
        let known=[outer,dynamics,rank,linear]
        var result:ConstrainedMotion?,failure:StationaryIslandFailureReason?
        do throws(MechanismError) { result=try solver.acceleration(system,sample:sample,drive:island.drive,policy:island.policy,
            work:&outer,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) } catch { failure = .mechanism(error) }
        var ledgers=[outer,dynamics,rank,linear],valid=true
        for i in ledgers.indices {
            if !IslandInvocation.valid(ledgers[i],known[i]) { ledgers[i]=known[i];valid=false }
            try IslandArithmetic.numerical { () throws(NumericalError) in try work.absorb(ledgers[i],reservedStorage:reserved) }
        }
        guard valid else { throw .supplierLedgerFailure(failure) }
        if let failure { throw failure };guard let result else { throw .invalidInput }
        guard result.temporalMeaning == .accelerationForce,result.basis == island.model.tree.layout,result.frame == system.input.snapshot.tree.worldFrame,
              result.time.bitPattern == system.input.snapshot.time.bitPattern,result.sourceVelocity == system.input.velocity,
              result.sourceSnapshot.bodies == system.input.snapshot.bodies,result.sourceSnapshot.frames == system.input.snapshot.frames,
              result.sourceSnapshot.joints == system.input.snapshot.joints,result.sourceSnapshot.coordinateRate == system.input.snapshot.coordinateRate,
              result.rowIDs == sample.rowIDs,result.rowMultipliers.count == sample.rowIDs.count,
              result.layout.coordinateIDs == sample.layout.coordinateIDs,result.layout.dimensions == sample.layout.dimensions,
              result.layout.scales == sample.layout.scales,result.layout.timeScale == sample.layout.timeScale,
              result.layout.revision == sample.layout.revision,result.generalizedReaction.count == system.velocityCount else { throw .sourceMismatch }
        guard result.rank.rank == sample.rowIDs.count,result.rank.reactionNullity == 0,result.rank.dependentRowIDs.isEmpty else { throw .rankAmbiguity }
        for body in system.input.snapshot.bodies {
            do throws(JointError) {
                guard try result.sourceSnapshot.geometricColumns(body:body.body) == system.input.snapshot.geometricColumns(body:body.body) else { throw JointError.invalidPolicy }
            } catch { throw .kinematics(error) }
        }
        for i in 0..<system.velocityCount {
            var reaction=0.0
            for r in sample.rowIDs.indices {
                try IslandArithmetic.charge(4,&work)
                reaction += sample.rows[r*system.velocityCount+i]*result.rowMultipliers[r]/sample.layout.scales[i]
            }
            guard reaction.isFinite,abs(reaction-result.generalizedReaction[i])*sample.layout.scales[i]/island.policy.dynamics.energyScale <= island.policy.originalTolerance else { throw .residualRejected }
        }
        return result
    }
    @inline(never)
    private func accept(system: RigidDynamicsSystem,island: StationaryMechanicalIsland,state: KinematicState,
                        acceleration: [Double],reaction: [Double],reserved: Int,work: inout NumericalWork) throws(StationaryIslandFailureReason) -> Double {
        let n=state.v.count
        guard acceleration.count == n,reaction.count == n,acceleration.allSatisfy({$0.isFinite}),reaction.allSatisfy({$0.isFinite}) else { throw .sourceMismatch }
        var energy=0.0
        for i in 0..<n {
            var applied=system.inertialBias[i]
            for j in 0..<n { try IslandArithmetic.charge(8,&work);applied += system.massMatrix[i*n+j]*acceleration[j];energy += 0.5*state.v[i]*system.massMatrix[i*n+j]*state.v[j] }
            guard applied.isFinite,abs(applied-island.drive[i]-reaction[i])*island.policy.dynamics.coordinateScales[i]/island.policy.dynamics.energyScale <= island.policy.originalTolerance else { throw .residualRejected }
        }
        guard energy.isFinite,energy >= 0 else { throw .residualRejected }
        var original=[Double](repeating:.nan,count:n)
        try IslandInvocation.local(work:&work,reserved:reserved) { (local:inout NumericalWork) throws(StationaryIslandFailureReason) in
            do throws(DynamicsError) { try equations.originalInertialForce(system,acceleration:acceleration,includeBias:true,into:&original,work:&local) }
            catch { throw .dynamics(error) }
        }
        guard original.count == n else { throw .sourceMismatch }
        for i in 0..<n {
            try IslandArithmetic.charge(5,&work)
            guard original[i].isFinite,abs(original[i]-island.drive[i]-reaction[i])*island.policy.dynamics.coordinateScales[i]/island.policy.dynamics.energyScale <= island.policy.originalTolerance else { throw .residualRejected }
        }
        if let constraints=island.constraints {
            for row in constraints.rows {
                var value=0.0
                for i in 0..<n { try IslandArithmetic.charge(4,&work);value += row.linear[i]*acceleration[i]*constraints.layout.timeScale*constraints.layout.timeScale/constraints.layout.scales[i] }
                guard value.isFinite,abs(value) <= island.policy.originalTolerance else { throw .residualRejected }
            }
        };return energy
    }
    private func positiveMass(_ matrix: [Double],n: Int,reserved:Int,work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        let square=try IslandArithmetic.product(n,n);try IslandArithmetic.storage(try IslandArithmetic.sum(reserved,square),&work)
        guard matrix.count == square else { throw .sourceMismatch };var factor=[Double](repeating:0,count:square)
        for i in 0..<n { for j in 0...i {
            try IslandArithmetic.charge(3,&work)
            guard matrix[i*n+j] == matrix[j*n+i],matrix[i*n+j].isFinite else { throw .residualRejected }
            var value=matrix[i*n+j]
            for k in 0..<j { try IslandArithmetic.charge(2,&work);value -= factor[i*n+k]*factor[j*n+k] }
            guard value.isFinite else { throw .residualRejected }
            if i == j { guard value > 0 else { throw .residualRejected };factor[i*n+j]=value.squareRoot() }
            else { factor[i*n+j]=value/factor[j*n+j] }
        } }
    }
}
