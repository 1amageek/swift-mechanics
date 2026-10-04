@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceConstrainedNormalImpulseSolver: ConstrainedNormalImpulseSolving {
    internal let mass: any RigidDynamicsSolving
    internal let equations: any RigidEquationComputing
    internal let laws: any ContactImpactPredicting
    internal let linear: any LinearSolving<Double>
    public init(mass: any RigidDynamicsSolving = DenseRigidDynamics(), equations: any RigidEquationComputing = RigidEquationKernel(),
                laws: any ContactImpactPredicting = ThresholdRestitutionPredictor(),
                linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.mass = mass; self.equations = equations; self.laws = laws; self.linear = linear
    }
    @inline(never)
    public func solve(_ prepared: PreparedConstrainedImpact, work: inout NumericalWork, contactWork: inout ContactWork,
                      cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedNormalImpulseResult {
        try ConstrainedImpactArithmetic.check(cancellation)
        let workspace = try inverseWorkspace(prepared,work:&work,cancellation:cancellation)
        let mode = try contactMode(workspace,work:&work)
        let prediction = try predict(mode,contactWork:&contactWork)
        let candidate = try simultaneous(mode,prediction:prediction,work:&work,cancellation:cancellation)
        return try accept(candidate,work:&work,cancellation:cancellation)
    }
    @inline(never)
    private func inverseWorkspace(_ source: PreparedConstrainedImpact, work: inout NumericalWork,
                                  cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedImpactWorkspace {
        let n = source.impact.system.velocityCount, m = source.retainedRowIDs.count, k = try ConstrainedImpactArithmetic.sum(m,1)
        let kn = try ConstrainedImpactArithmetic.product(k,n), kk = try ConstrainedImpactArithmetic.product(k,k)
        guard kk <= source.policy.maximumFactorEntries,
              try ConstrainedImpactArithmetic.product(n,n) <= source.policy.maximumFactorEntries else { throw ConstrainedImpactError(.capacityExceeded) }
        let reserved = try ConstrainedImpactArithmetic.sum(source.impact.system.scalarStorage,
            try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(3,kn),
                try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(3,kk),
                    try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(16,n),try ConstrainedImpactArithmetic.product(8,k)))))
        try ConstrainedImpactArithmetic.storage(reserved,&work)
        var inverse = [Double](repeating:0,count:kn), schur = [Double](repeating:0,count:kk)
        for i in 0..<k {
            try ConstrainedImpactArithmetic.check(cancellation)
            let row = physicalRow(source,index:i)
            let values = try inverseAction(source,row:row,reserved:reserved,work:&work)
            guard values.count == n, values.allSatisfy({ $0.isFinite }) else { throw ConstrainedImpactError(.sourceMismatch) }
            for v in 0..<n { inverse[i*n+v] = values[v] }
            for j in 0..<k {
                schur[j*k+i] = try ConstrainedImpactArithmetic.dot(physicalRow(source,index:j),values,work:&work)
            }
        }
        return ConstrainedImpactWorkspace(source:source,inverse:inverse,schur:schur,reserved:reserved)
    }
    @inline(never)
    internal func physicalRow(_ source: PreparedConstrainedImpact, index: Int) -> [Double] {
        let n = source.impact.system.velocityCount
        if index == source.retainedRowIDs.count { return source.impact.normalRows }
        // A bounded row copy supplies the existing mass-vector protocol; it cannot borrow a slice.
        return Array(source.retainedRows[(index*n)..<((index+1)*n)])
    }
    @inline(never)
    private func contactMode(_ workspace: ConstrainedImpactWorkspace, work: inout NumericalWork) throws(ConstrainedImpactError) -> ConstrainedImpactMode {
        let m = workspace.count-1, k = workspace.count
        var gram = [Double](repeating:0,count:m*m), coupling = [Double](repeating:0,count:m)
        for i in 0..<m {
            coupling[i] = workspace.schur[i*k+m]
            for j in 0..<m { gram[i*m+j] = workspace.schur[i*k+j] }
        }
        let solved = try linearAction(gram,rhs:coupling,count:m,source:workspace.source,reserved:workspace.reserved,work:&work)
        let correction = try ConstrainedImpactArithmetic.dot(coupling,solved,work:&work)
        let inverseMass = try ConstrainedImpactArithmetic.finite(workspace.schur[m*k+m]-correction)
        guard inverseMass > workspace.source.policy.minimumEffectiveInverseMass else { throw ConstrainedImpactError(.blockedNormalMode) }
        let before = try ConstrainedImpactArithmetic.dot(workspace.source.impact.normalRows,workspace.source.impact.system.input.velocity,work:&work)
        guard before < -workspace.source.policy.impact.speedTolerance else { throw ConstrainedImpactError(.hybrid(.grazing)) }
        return ConstrainedImpactMode(workspace:workspace,before:before,inverseMass:inverseMass)
    }
    @inline(never)
    private func predict(_ mode: ConstrainedImpactMode, contactWork: inout ContactWork) throws(ConstrainedImpactError) -> ContactImpactPrediction {
        let energy = try ConstrainedImpactArithmetic.finite(0.5*(mode.before/mode.inverseMass)*mode.before)
        let value = try ConstrainedImpactInvocation.contact(work:&contactWork) { (work: inout ContactWork) throws(ConstrainedImpactError) in
            do throws(ContactLawError) { return try laws.predict(pair:mode.workspace.source.impact.contacts[0].law,approachSpeed:-mode.before,
                                         incomingNormalEnergy:energy,work:&work) }
            catch { throw ConstrainedImpactError(.contact(error)) }
        }
        let p = mode.workspace.source.policy.impact, e = value.effectiveRestitution
        guard case .separateImpact(let selectedRestitution,let threshold) = mode.workspace.source.impact.contacts[0].law.lossPolicy else {
            throw ConstrainedImpactError(.sourceMismatch)
        }
        let expectedRestitution = -mode.before < threshold ? 0 : selectedRestitution
        let limit = try ConstrainedImpactArithmetic.finite(p.energyAbsolute+p.energyRelative*abs(energy))
        guard e == expectedRestitution, e.isFinite, e >= 0, e <= 1, value.reboundSpeed.isFinite, value.lostNormalEnergy.isFinite,
              value.retainedNormalEnergy.isFinite, value.lostNormalEnergy >= 0, value.retainedNormalEnergy >= 0,
              abs(value.reboundSpeed+e*mode.before) <= p.speedTolerance,
              abs(value.retainedNormalEnergy-energy*e*e) <= limit,
              abs(value.lostNormalEnergy-energy*(1-e*e)) <= limit else { throw ConstrainedImpactError(.residualRejected) }
        return value
    }
    @inline(never)
    private func simultaneous(_ mode: ConstrainedImpactMode, prediction: ContactImpactPrediction, work: inout NumericalWork,
                              cancellation: HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedImpactCandidate {
        try ConstrainedImpactArithmetic.check(cancellation)
        let w = mode.workspace, k = w.count, n = w.velocityCount
        var rhs = [Double](repeating:0,count:k)
        rhs[k-1] = try ConstrainedImpactArithmetic.finite(-(1+prediction.effectiveRestitution)*mode.before)
        let impulses = try linearAction(w.schur,rhs:rhs,count:k,source:w.source,reserved:w.reserved,work:&work)
        let normalResidual = try ConstrainedImpactArithmetic.finite(abs(mode.inverseMass*impulses[k-1]+(1+prediction.effectiveRestitution)*mode.before))
        guard impulses[k-1] >= 0, normalResidual <= w.source.policy.impact.speedTolerance else { throw ConstrainedImpactError(.residualRejected) }
        var delta = [Double](repeating:0,count:n), applied = delta, reaction = delta, velocity = delta
        try ConstrainedImpactArithmetic.charge(try ConstrainedImpactArithmetic.product(6,try ConstrainedImpactArithmetic.product(k,n)),&work)
        for i in 0..<k {
            let row = physicalRow(w.source,index:i)
            for v in 0..<n {
                delta[v] = try ConstrainedImpactArithmetic.finite(delta[v]+w.inverseRows[i*n+v]*impulses[i])
                applied[v] = try ConstrainedImpactArithmetic.finite(applied[v]+row[v]*impulses[i])
                if i < k-1 { reaction[v] = try ConstrainedImpactArithmetic.finite(reaction[v]+row[v]*impulses[i]) }
            }
        }
        for v in 0..<n { velocity[v] = try ConstrainedImpactArithmetic.finite(w.source.impact.system.input.velocity[v]+delta[v]) }
        let after = try ConstrainedImpactArithmetic.dot(w.source.impact.normalRows,velocity,work:&work)
        return ConstrainedImpactCandidate(mode:mode,prediction:prediction,impulses:impulses,delta:delta,
            velocity:velocity,applied:applied,reaction:reaction,after:after)
    }
}
