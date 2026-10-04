
public struct MassWeightedMechanismSolver: ConstrainedMechanismSolving {
    private let dynamics: any RigidDynamicsSolving
    private let equations: any RigidEquationComputing
    private let rankAnalyzer: any ConstraintRankAnalyzing
    private let linear: any LinearSolving<Double>
    public init(dynamics: any RigidDynamicsSolving = DenseRigidDynamics(), equations: any RigidEquationComputing = RigidEquationKernel(),
                rank: any ConstraintRankAnalyzing = WeightedConstraintAssembler(), linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.dynamics=dynamics; self.equations=equations; rankAnalyzer=rank; self.linear=linear
    }
    @inline(never)
    public func acceleration(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample, drive: [Double],
                             policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                             rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try admit(system,sample:sample,policy:policy,work:&work)
        guard drive.count == system.velocityCount, drive.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        let free=try dynamicsCall(work:&dynamicsWork) { ledger throws(DynamicsError) in
            try dynamics.forward(system,driveForce:drive,policy:policy.dynamics,work:&ledger)
        }
        guard free.acceleration.count == system.velocityCount else { throw .invalidShape }
        return try solve(system,sample:sample,base:free.acceleration,drive:drive,impulse:false,policy:policy,
            work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    @inline(never)
    public func reconcileVelocity(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample,
                                  policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                                  rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try admit(system,sample:sample,policy:policy,work:&work)
        return try solve(system,sample:sample,base:system.input.velocity,drive:[],impulse:true,policy:policy,
            work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    @inline(never)
    private func admit(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample, policy: MechanismSolvePolicy,
                       work: inout NumericalWork) throws(MechanismError) {
        try MechanismArithmetic.check(policy)
        let n=system.velocityCount,m=sample.rowIDs.count
        guard n > 0, n <= policy.maximumCoordinates, m > 0, m <= policy.maximumRows else { throw .capacityExceeded }
        let entries=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(n,m) }
        let matrixEntries=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(n,n) }
        guard sample.layout.revision == system.input.snapshot.tree.revision,
              sample.layout.scales == policy.dynamics.coordinateScales, sample.layout.timeScale == policy.dynamics.timeScale else { throw .staleBinding }
        guard sample.layout.scales.count == n, sample.rows.count == entries, sample.drift.count == m,
              sample.accelerationBias.count == m, system.massMatrix.count == matrixEntries, system.inertialBias.count == n,
              sample.rows.allSatisfy({ $0.isFinite }), sample.drift.allSatisfy({ $0.isFinite }),
              sample.accelerationBias.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        // Retained columns, Gram, output and scalar-equivalent index records. Supplier reserves are separate.
        try MechanismArithmetic.numerical { () throws(NumericalError) in
            let columns=try NumericalWork.product(n,m), square=try NumericalWork.product(m,m)
            let count=try NumericalWork.sum(try NumericalWork.product(2,columns),try NumericalWork.sum(square,try NumericalWork.sum(try NumericalWork.product(8,n),try NumericalWork.product(6,m))))
            try work.requireStorage(count)
        }
        let admissionCharge=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(entries,try NumericalWork.product(m,2)) }
        try MechanismArithmetic.charge(admissionCharge, &work)
    }
    @inline(never)
    private func solve(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample, base: [Double], drive:[Double], impulse:Bool,
                       policy:MechanismSolvePolicy, work:inout NumericalWork, dynamicsWork:inout NumericalWork,
                       rankWork:inout NumericalWork, linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        let n=system.velocityCount,m=sample.rowIDs.count,t=sample.layout.timeScale,e=policy.dynamics.energyScale,s=sample.layout.scales
        try MechanismArithmetic.charge(1,&rankWork)
        let before=rankWork
        var rank:ConstraintRankEvidence?, rankFailure:ConstraintError?
        do throws(ConstraintError) { rank=try rankAnalyzer.rank(sample,policy:policy.constraints,work:&rankWork) } catch { rankFailure=error }
        guard MechanismArithmetic.preserved(before,rankWork) else { rankWork=before; throw .supplierLedgerReplaced }
        if let rankFailure { throw .constraint(rankFailure) }
        guard let rank,rank.rank >= 0,rank.rank <= min(n,m),rank.independentRows.count == rank.rank,
              rank.reactionNullity == m-rank.rank else { throw .invalidRankEvidence }
        for i in rank.independentRows.indices {
            guard sample.rowIDs.indices.contains(rank.independentRows[i]), !rank.independentRows[..<i].contains(rank.independentRows[i]) else { throw .invalidRankEvidence }
        }
        let r=rank.rank, factor=impulse ? t : t*t
        var columns=[Double](repeating:0,count:r*n), rhs=[Double](repeating:0,count:r), gram=[Double](repeating:0,count:r*r)
        var physicalRHS=[Double](repeating:0,count:n)
        for k in 0..<r {
            try MechanismArithmetic.check(policy)
            let row=rank.independentRows[k]
            for i in 0..<n { try MechanismArithmetic.charge(2,&work); physicalRHS[i]=try MechanismArithmetic.finite(e*sample.rows[row*n+i]/s[i]) }
            let column=try dynamicsCall(work:&dynamicsWork) { ledger throws(DynamicsError) in
                try dynamics.inverseMassProduct(system,rightHandSide:physicalRHS,policy:policy.dynamics,work:&ledger)
            }
            guard column.acceleration.count == n else { throw .invalidShape }
            for i in 0..<n { columns[k*n+i]=column.acceleration[i] }
            var value=impulse ? sample.drift[row] : sample.accelerationBias[row]
            for i in 0..<n { try MechanismArithmetic.charge(4,&work); value=try MechanismArithmetic.finite(value+sample.rows[row*n+i]*base[i]*factor/s[i]) }
            rhs[k] = -value
        }
        for i in 0..<r { for j in 0..<r {
            var value=0.0
            for k in 0..<n { try MechanismArithmetic.charge(4,&work); value=try MechanismArithmetic.finite(value+sample.rows[rank.independentRows[i]*n+k]*columns[j*n+k]*t*t/s[k]) }
            gram[i*r+j]=value
        } }
        var selected=[Double]()
        if r > 0 { selected=try linearSolve(gram,rhs:rhs,policy:policy,work:&linearWork) }
        guard selected.count == r,selected.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        var values=base, multipliers=[Double](repeating:0,count:m), reaction=[Double](repeating:0,count:n)
        for k in 0..<r {
            let row=rank.independentRows[k]
            try MechanismArithmetic.charge(2,&work)
            multipliers[row]=try MechanismArithmetic.finite(selected[k]*e*(impulse ? t : 1))
            for i in 0..<n {
                try MechanismArithmetic.charge(7,&work)
                values[i]=try MechanismArithmetic.finite(values[i]+columns[k*n+i]*selected[k]*(impulse ? t : 1))
                reaction[i]=try MechanismArithmetic.finite(reaction[i]+sample.rows[row*n+i]*multipliers[row]/s[i])
            }
        }
        let acceptance=MechanismAcceptanceContext(system:system,sample:sample,base:base,values:values,drive:drive,
            multipliers:multipliers,reaction:reaction,rank:rank,impulse:impulse,policy:policy)
        return try accept(acceptance,work:&work,dynamicsWork:&dynamicsWork)
    }
    @inline(never)
    private func accept(_ context:MechanismAcceptanceContext,work:inout NumericalWork,
                        dynamicsWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        // Preserve the original buffer allocation order; future publication provenance exists only in its final phase.
        var original=[Double](repeating:0,count:context.count)
        let rowResidual=try acceptOriginalRows(context,work:&work)
        let energy=try originalPhysicalForce(context,original:&original,work:&work,dynamicsWork:&dynamicsWork)
        let physicalResidual=try acceptOriginalMomentum(context,original:original,work:&work)
        try MechanismArithmetic.check(context.policy)
        return publishAcceptedMotion(context,rowResidual:rowResidual,physicalResidual:physicalResidual,energy:energy)
    }
    @inline(never)
    private func acceptOriginalRows(_ context:MechanismAcceptanceContext,work:inout NumericalWork) throws(MechanismError) -> Double {
        let n=context.count,t=context.timeScale,s=context.scales
        var rowResidual=0.0
        for row in context.sample.rowIDs.indices {
            var value=context.impulse ? context.sample.drift[row] : context.sample.accelerationBias[row]
            for i in 0..<n {
                try MechanismArithmetic.charge(4,&work)
                value=try MechanismArithmetic.finite(value+context.sample.rows[row*n+i]*context.values[i]*(context.impulse ? t : t*t)/s[i])
            }
            rowResidual=max(rowResidual,abs(value))
            guard abs(value) <= context.policy.originalTolerance else { throw .originalConstraint(row:context.sample.rowIDs[row],residual:abs(value)) }
        }
        return rowResidual
    }
    @inline(never)
    private func originalPhysicalForce(_ context:MechanismAcceptanceContext,original:inout [Double],
                                       work:inout NumericalWork,dynamicsWork:inout NumericalWork) throws(MechanismError) -> Double {
        if context.impulse { return try originalImpulseMomentum(context,original:&original,work:&work) }
        try originalAccelerationForce(context,original:&original,dynamicsWork:&dynamicsWork)
        return 0
    }
    @inline(never)
    private func originalImpulseMomentum(_ context:MechanismAcceptanceContext,original:inout [Double],
                                         work:inout NumericalWork) throws(MechanismError) -> Double {
        let n=context.count
        var energy=0.0
        for i in 0..<n { for j in 0..<n {
            try MechanismArithmetic.charge(8,&work)
            original[i]=try MechanismArithmetic.finite(original[i]+context.system.massMatrix[i*n+j]*(context.values[j]-context.base[j]))
            energy=try MechanismArithmetic.finite(energy+0.5*context.system.massMatrix[i*n+j]*(context.values[i]*context.values[j]-context.base[i]*context.base[j]))
        } }
        return energy
    }
    @inline(never)
    private func originalAccelerationForce(_ context:MechanismAcceptanceContext,original:inout [Double],
                                          dynamicsWork:inout NumericalWork) throws(MechanismError) {
        try MechanismArithmetic.charge(1,&dynamicsWork)
        let before=dynamicsWork
        var failure:DynamicsError?
        do throws(DynamicsError) {
            try equations.originalInertialForce(context.system,acceleration:context.values,includeBias:true,into:&original,work:&dynamicsWork)
        } catch { failure=error }
        guard MechanismArithmetic.preserved(before,dynamicsWork) else { dynamicsWork=before; throw .supplierLedgerReplaced }
        if let failure { throw .dynamics(failure) }
        guard original.count == context.count else { throw .invalidShape }
    }
    @inline(never)
    private func acceptOriginalMomentum(_ context:MechanismAcceptanceContext,original:[Double],
                                        work:inout NumericalWork) throws(MechanismError) -> Double {
        let n=context.count,t=context.timeScale,e=context.energyScale,s=context.scales
        var physicalResidual=0.0
        for i in 0..<n {
            try MechanismArithmetic.charge(7,&work)
            let expected:Double
            if context.impulse { expected=context.reaction[i] }
            else {
                do throws(DynamicsError) { expected=context.drive[i]+(try context.system.forces.total(at:i))+context.reaction[i] }
                catch { throw .dynamics(error) }
            }
            let value=try MechanismArithmetic.finite(abs(original[i]-expected)*s[i]/(e*(context.impulse ? t : 1)))
            physicalResidual=max(physicalResidual,value)
            guard value <= context.policy.originalTolerance else { throw .originalMomentum(residual:value) }
        }
        return physicalResidual
    }
    @inline(never)
    private func publishAcceptedMotion(_ context:MechanismAcceptanceContext,rowResidual:Double,
                                       physicalResidual:Double,energy:Double) -> ConstrainedMotion {
        ConstrainedMotion(values:context.values,multipliers:context.multipliers,ids:context.sample.rowIDs,reaction:context.reaction,rank:context.rank,
            layout:context.sample.layout,basis:context.system.input.snapshot.tree.layout,frame:context.system.input.snapshot.tree.worldFrame,
            source:context.system.input.snapshot,velocity:context.system.input.velocity,rowResidual:rowResidual,physicalResidual:physicalResidual,
            energy:context.impulse ? energy : nil,time:context.system.input.snapshot.time,
            meaning:context.impulse ? .instantaneousVelocityImpulse : .accelerationForce)
    }
    private func dynamicsCall(work:inout NumericalWork,_ call:(inout NumericalWork) throws(DynamicsError) -> DynamicsSolution) throws(MechanismError) -> DynamicsSolution {
        try MechanismArithmetic.charge(1,&work)
        let before=work
        var value:DynamicsSolution?,failure:DynamicsError?
        do throws(DynamicsError) { value=try call(&work) } catch { failure=error }
        guard MechanismArithmetic.preserved(before,work) else { work=before; throw .supplierLedgerReplaced }
        if let failure { throw .dynamics(failure) }
        guard let value else { throw .invalidShape }; return value
    }
    private func linearSolve(_ values:[Double],rhs:[Double],policy:MechanismSolvePolicy,work:inout NumericalWork) throws(MechanismError) -> [Double] {
        let matrix=try MechanismArithmetic.numerical { () throws(NumericalError) in try DenseMatrix(rows:rhs.count,columns:rhs.count,values:values) }
        let budget=try MechanismArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:0) }
        let result:LinearSolution<Double>
        do throws(NumericalError) { result=try linear.solve(matrix,rightHandSide:rhs,capability:policy.constraints.linearCapability,tolerance:policy.constraints.linearTolerance,budget:budget) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        try MechanismArithmetic.numerical { () throws(NumericalError) in try work.absorb(result.diagnostics.work,reservedStorage:0) }
        return result.values
    }
}
