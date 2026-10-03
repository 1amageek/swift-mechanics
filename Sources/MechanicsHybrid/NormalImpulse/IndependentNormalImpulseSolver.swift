import MechanicsDynamics
import MechanicsJoints
import MechanicsNumerics
import MechanicsContactLaws

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct IndependentNormalImpulseSolver: NormalImpulseSolving {
    private let mass: any RigidDynamicsSolving
    private let equations: any RigidEquationComputing
    private let laws: any ContactImpactPredicting
    public init(mass: any RigidDynamicsSolving = DenseRigidDynamics(), equations: any RigidEquationComputing = RigidEquationKernel(),
                laws: any ContactImpactPredicting = ThresholdRestitutionPredictor()) {
        self.mass=mass; self.equations=equations; self.laws=laws
    }
    @inline(never)
    public func solve(_ impact: PreparedImpact, policy: HybridPolicy, massPolicy: DynamicsSolvePolicy,
                      work: inout NumericalWork, contactWork: inout ContactWork, cancellation: HybridCancellation) throws(HybridError) -> NormalImpulseResult {
        try cancellation.check()
        let n=impact.system.velocityCount, m=impact.contacts.count
        guard n == policy.impulseScales.count, n <= policy.maximumVelocities, m > 0, m <= policy.maximumContacts else { throw .invalidInput }
        let mn=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(m,n) }
        let mm=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(m,m) }
        let storage=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(impact.system.scalarStorage,try NumericalWork.sum(try NumericalWork.product(2,mn),try NumericalWork.sum(mm,try NumericalWork.sum(try NumericalWork.product(8,n),try NumericalWork.product(5,m))))) }
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(storage) }
        var inverseRows=[Double](repeating:0,count:mn), w=[Double](repeating:0,count:mm), row=[Double](repeating:0,count:n)
        var before=[Double](repeating:0,count:m), rebound=[Double](repeating:0,count:m), impulses=[Double](repeating:0,count:m)
        for i in 0..<m {
            try cancellation.check()
            for k in 0..<n { row[k]=impact.normalRows[i*n+k] }
            let result: DynamicsSolution
            result=try ImpactSupplierWork.inverse(mass,system:impact.system,rhs:row,policy:massPolicy,reserved:storage,work:&work)
            guard result.acceleration.count == n else { throw .invalidInput }
            for k in 0..<n { inverseRows[i*n+k]=result.acceleration[k] }
            before[i]=try ImpactArithmetic.dot(row,impact.system.input.velocity,work:&work)
            for j in 0..<m {
                try ImpactArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(2,n)) }
                for k in 0..<n { w[j*m+i]=try ImpactArithmetic.finite(w[j*m+i]+impact.normalRows[j*n+k]*result.acceleration[k]) }
            }
        }
        for i in 0..<m {
            guard w[i*m+i].isFinite, w[i*m+i] > 0 else { throw .residualRejected }
            for j in 0..<i {
                let scale=(w[i*m+i].squareRoot())*(w[j*m+j].squareRoot())
                guard scale.isFinite, scale > 0 else { throw .nonFinite }
                // FIXME(INCOMPLETE_IMPLEMENTATION): Coupled simultaneous contacts reach this solver admission.
                // A selected multi-contact impulse law with original complementarity/energy evidence is required before success.
                guard abs(w[i*m+j]/scale) <= policy.independenceTolerance,
                      abs(w[j*m+i]/scale) <= policy.independenceTolerance else { throw .coupledModes }
            }
        }
        var loss=0.0
        for i in 0..<m {
            try cancellation.check()
            guard before[i] < -policy.speedTolerance else { throw .grazing }
            let energy=try ImpactArithmetic.finite(0.5*(before[i]/w[i*m+i])*before[i])
            let prediction: ContactImpactPrediction
            do { prediction=try laws.predict(pair:impact.contacts[i].law,approachSpeed:-before[i],incomingNormalEnergy:energy,work:&contactWork) }
            catch { throw .contact(error) }
            let e=prediction.effectiveRestitution
            guard e.isFinite, e >= 0, e <= 1, prediction.reboundSpeed.isFinite,
                  abs(prediction.reboundSpeed+e*before[i]) <= policy.speedTolerance,
                  prediction.lostNormalEnergy.isFinite, prediction.lostNormalEnergy >= 0 else { throw .residualRejected }
            impulses[i]=try ImpactArithmetic.finite(-(1+e)*before[i]/w[i*m+i])
            rebound[i]=prediction.reboundSpeed; loss=try ImpactArithmetic.finite(loss+prediction.lostNormalEnergy)
        }
        var delta=[Double](repeating:0,count:n), applied=[Double](repeating:0,count:n), velocity=impact.system.input.velocity
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(4,mn)) }
        for i in 0..<m { for k in 0..<n {
            delta[k]=try ImpactArithmetic.finite(delta[k]+inverseRows[i*n+k]*impulses[i])
            applied[k]=try ImpactArithmetic.finite(applied[k]+impact.normalRows[i*n+k]*impulses[i])
        } }
        for k in 0..<n { velocity[k]=try ImpactArithmetic.finite(velocity[k]+delta[k]) }
        var original=[Double](repeating:0,count:n)
        try ImpactSupplierWork.action(equations,system:impact.system,values:delta,into:&original,reserved:storage,work:&work)
        var momentum=0.0, momentumScale=0.0
        for k in 0..<n {
            momentum=max(momentum,abs(original[k]-applied[k])/policy.impulseScales[k])
            momentumScale=max(momentumScale,max(abs(original[k]),abs(applied[k]))/policy.impulseScales[k])
        }
        var after=[Double](repeating:0,count:m), lawResidual=0.0
        for i in 0..<m {
            for k in 0..<n { row[k]=impact.normalRows[i*n+k] }
            after[i]=try ImpactArithmetic.dot(row,velocity,work:&work)
            lawResidual=max(lawResidual,abs(after[i]-rebound[i]))
        }
        try ImpactSupplierWork.action(equations,system:impact.system,values:impact.system.input.velocity,into:&original,reserved:storage,work:&work)
        let energyBefore=try ImpactArithmetic.finite(0.5*ImpactArithmetic.dot(impact.system.input.velocity,original,work:&work))
        try ImpactSupplierWork.action(equations,system:impact.system,values:velocity,into:&original,reserved:storage,work:&work)
        let energyAfter=try ImpactArithmetic.finite(0.5*ImpactArithmetic.dot(velocity,original,work:&work))
        let residual=try ImpactArithmetic.finite(abs(energyBefore-energyAfter-loss))
        let momentumLimit=try ImpactArithmetic.finite(policy.momentumAbsolute+policy.momentumRelative*momentumScale)
        let energyLimit=try ImpactArithmetic.finite(policy.energyAbsolute+policy.energyRelative*max(abs(energyBefore),abs(energyAfter)))
        guard momentum.isFinite, momentum <= momentumLimit, lawResidual <= policy.speedTolerance,
              energyBefore >= -policy.energyAbsolute, energyAfter >= -policy.energyAbsolute,
              energyAfter <= energyBefore+energyLimit, residual <= energyLimit else { throw .residualRejected }
        try cancellation.check()
        return NormalImpulseResult(time:impact.system.input.snapshot.time,ids:impact.contacts.map { $0.eventID },impulses:impulses,velocity:velocity,
            before:before,after:after,energyBefore:energyBefore,energyAfter:energyAfter,loss:loss,
            momentumResidual:momentum,lawResidual:lawResidual,energyResidual:residual)
    }
}
