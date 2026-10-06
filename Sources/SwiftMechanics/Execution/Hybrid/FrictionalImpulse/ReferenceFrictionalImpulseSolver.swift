@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceFrictionalImpulseSolver: FrictionalImpulseSolving {
    private let supplier: FrictionalImpulseSupplier
    public init(mass: any PhysicalRigidDynamicsSolving = DenseRigidDynamics(),
                linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        supplier=FrictionalImpulseSupplier(mass:mass,linear:linear)
    }
    @inline(never)
    public func solve(_ input: FrictionalImpulseInput, policy: FrictionalImpulsePolicy,
                      work: inout NumericalWork, loadWork: inout LoadWork,
                      contactWork: inout ContactWork) throws(FrictionalImpulseFailure) -> FrictionalImpulseResult {
        let a=FrictionalImpulseArithmetic.self
        do { try loadWork.charge(0) } catch { throw FrictionalImpulseFailure(.loads(error)) }
        let source=try FrictionalImpulseSource.prepare(input,policy:policy,work:&work)
        let system=try source.assemble(snapshot:source.snapshot,velocity:input.state.v,policy:policy,loadWork:&loadWork,work:&work)
        let n=system.velocityCount
        var w=[Double](repeating:0,count:9), rhs=[Double](repeating:0,count:n)
        for column in 0..<3 {
            try a.check(policy)
            for i in 0..<n { rhs[i]=source.rows[column*n+i] }
            let inverse=try supplier.inverse(system,rhs:rhs,policy:policy,reserved:source.reserved,work:&work)
            try a.charge(a.product(6,n),&work)
            for row in 0..<3 {
                var image=0.0
                for i in 0..<n { image=try a.finite(image+source.rows[row*n+i]*inverse[i]) }
                w[row*3+column]=image
            }
        }
        try a.charge(128,&work)
        for i in 0..<3 {
            guard try a.finite(policy.massScaleKg*w[i*3+i]) > policy.tangentTolerance.pivotThreshold else { throw FrictionalImpulseFailure(.singularTangent) }
            for j in 0..<i {
                let scale=try a.finite(w[i*3+i].squareRoot()*w[j*3+j].squareRoot())
                guard scale > 0,
                      abs(try a.finite((w[i*3+j]-w[j*3+i])/scale)) <= policy.hybrid.independenceTolerance else { throw FrictionalImpulseFailure(.invalidSupplierOutput) }
                if j == 0 {
                    // FIXME(INCOMPLETE_IMPLEMENTATION): General coupled normal/tangent Delassus requests reach this selected law.
                    // A nonassociated coupled restitution/Coulomb solve and original-row evidence are required before success.
                    guard abs(try a.finite(w[i*3+j]/scale)) <= policy.hybrid.independenceTolerance,
                          abs(try a.finite(w[j*3+i]/scale)) <= policy.hybrid.independenceTolerance else { throw FrictionalImpulseFailure(.coupledNormalTangent) }
                }
            }
        }
        guard source.before[0] < -policy.hybrid.speedTolerance else { throw FrictionalImpulseFailure(.nonapproaching) }
        let incoming=try a.finite(0.5*(source.before[0]/w[0])*source.before[0])
        let prediction: ContactImpactPrediction
        do { prediction=try ThresholdRestitutionPredictor().predict(pair:input.contact.law,approachSpeed:-source.before[0],incomingNormalEnergy:incoming,work:&contactWork) }
        catch { throw FrictionalImpulseFailure(.contact(error)) }
        let e=prediction.effectiveRestitution, normal=try a.finite(-(1+e)*source.before[0]/w[0])
        let expectedLoss=try a.finite(incoming*(1-e*e))
        let lossLimit=try a.finite(policy.hybrid.energyAbsolute+policy.hybrid.energyRelative*incoming)
        guard e.isFinite, e >= 0, e <= 1, normal > 0, prediction.reboundSpeed.isFinite,
              abs(try a.finite(prediction.reboundSpeed+e*source.before[0])) <= policy.hybrid.speedTolerance,
              prediction.lostNormalEnergy.isFinite, prediction.lostNormalEnergy >= 0,
              abs(try a.finite(prediction.lostNormalEnergy-expectedLoss)) <= lossLimit,
              abs(try a.finite(prediction.retainedNormalEnergy+prediction.lostNormalEnergy-incoming)) <= lossLimit else { throw FrictionalImpulseFailure(.invalidSupplierOutput) }
        let tangent=try FrictionalImpulseTangent.solve(w:w,before:source.before,normal:normal,supplier:supplier,policy:policy,reserved:source.reserved,work:&work)
        let impulse=[normal,tangent.values[0],tangent.values[1]]
        try a.charge(a.product(10,n),&work)
        for i in 0..<n { rhs[i]=try a.finite(source.rows[i]*impulse[0]+source.rows[n+i]*impulse[1]+source.rows[2*n+i]*impulse[2]) }
        // This final original mass query owns the returned jump, not a sum of cached inverse rows.
        let delta=try supplier.inverse(system,rhs:rhs,policy:policy,reserved:source.reserved,work:&work)
        var velocity=input.state.v
        for i in 0..<n { velocity[i]=try a.finite(velocity[i]+delta[i]) }
        let stateAfter=try a.source { try KinematicState(revision:input.state.revision,time:input.state.time,q:input.state.q,
            v:velocity,acceleration:[Double](repeating:0,count:n),prescribedAnchors:input.state.prescribedAnchors) }
        try a.check(policy)
        try a.charge(a.sum(try a.product(8192,input.tree.bodies.count),try a.product(1024,try a.product(input.tree.bodies.count,n))),&work)
        let snapshotAfter=try a.source { try TreeKinematicsEvaluator().evaluate(input.tree,state:stateAfter,policy:policy.joints) }
        let systemAfter=try source.assemble(snapshot:snapshotAfter,velocity:velocity,policy:policy,loadWork:&loadWork,work:&work)
        return try FrictionalImpulseAcceptance.finish(source:source,before:system,after:systemAfter,state:stateAfter,snapshot:snapshotAfter,
            w:w,impulse:impulse,delta:delta,applied:rhs,tangent:tangent,prediction:prediction,policy:policy,work:&work,loadWork:loadWork,contactWork:contactWork)
    }
}
