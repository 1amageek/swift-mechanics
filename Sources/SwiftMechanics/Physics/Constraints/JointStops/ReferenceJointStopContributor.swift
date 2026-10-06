public struct ReferenceJointStopContributor: JointStopContributing, Sendable {
    private let mass: JointStopMassInvocation
    public init(mass: any PhysicalRigidDynamicsSolving = DenseRigidDynamics()) { self.mass=JointStopMassInvocation(mass:mass) }
    public func prepare(_ input: JointStopInput, policy: JointStopPolicy,
                        work: inout NumericalWork) throws(JointStopFailure) -> PreparedJointStop {
        try JointStopPreparation.make(input,policy:policy,work:&work)
    }
    @inline(never)
    public func impact(_ prepared: PreparedJointStop, side: JointStopSide, policy: JointStopPolicy,
                       work: inout NumericalWork, loadWork: inout LoadWork,
                       contactWork: inout ContactWork) throws(JointStopFailure) -> JointStopImpactResult {
        let a=JointStopArithmetic.self, input=prepared.input, metric=input.definition.metersPerCoordinateUnit
        try JointStopPreparation.admit(input,policy:policy,work:&work)
        do throws(LoadError) { try loadWork.charge(0) } catch { throw JointStopFailure(.loads(error)) }
        let row: [Double], gap: Double, otherGap: Double, rate: Double
        switch side {
        case .lower: row=prepared.lowerRow; gap=prepared.gaps.lowerGap; otherGap=prepared.gaps.upperGap; rate=prepared.gaps.lowerGapRate
        case .upper: row=prepared.upperRow; gap=prepared.gaps.upperGap; otherGap=prepared.gaps.lowerGap; rate=prepared.gaps.upperGapRate
        }
        try a.charge(32,&work)
        let normalGap=try a.finite(metric*gap), oppositeGap=try a.finite(metric*otherGap)
        guard abs(normalGap) <= policy.gapToleranceMeters else { throw JointStopFailure(.nonboundary) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): A tolerance-sized lower/upper simultaneous stop tie reaches impact admission.
        // A selected multi-bound law and original coupled acceptance must exist before this tie can succeed.
        guard oppositeGap > policy.gapToleranceMeters else { throw JointStopFailure(.ambiguousBoundary) }
        let normalRate=try a.finite(metric*rate)
        let rowRate=try a.dot(row,input.state.state.v,work:&work)
        guard abs(try a.finite(normalRate-rowRate)) <= policy.speedToleranceMetersPerSecond else {
            throw JointStopFailure(.normalRateRejected(value:abs(normalRate-rowRate),threshold:policy.speedToleranceMetersPerSecond))
        }
        guard normalRate < -policy.speedToleranceMetersPerSecond else { throw JointStopFailure(.nonapproaching) }
        let before=try JointStopMassInvocation.assemble(prepared,source:prepared.source,policy:policy,work:&work,loadWork:&loadWork)
        let inverseRow=try mass.inverse(before,rhs:row,prepared:prepared,policy:policy,work:&work)
        let w=try a.dot(row,inverseRow,work:&work)
        guard w > policy.minimumInverseMassPerKilogram else { throw JointStopFailure(.singularNormalMass) }
        let incoming=try a.finite(0.5*(normalRate/w)*normalRate)
        let prediction: ContactImpactPrediction
        do throws(ContactLawError) { prediction=try ThresholdRestitutionPredictor().predict(pair:input.definition.restitutionLaw,
            approachSpeed:-normalRate,incomingNormalEnergy:incoming,work:&contactWork) }
        catch { throw JointStopFailure(.contact(error)) }
        let e=prediction.effectiveRestitution
        let normalImpulse=try a.finite(-(1+e)*normalRate/w)
        let loss=try a.finite(incoming*(1-e*e)), lossLimit=try a.threshold(policy.energyToleranceJoules,scale:incoming)
        guard e.isFinite, e >= 0, e <= 1, normalImpulse > 0, prediction.reboundSpeed.isFinite,
              abs(try a.finite(prediction.reboundSpeed+e*normalRate)) <= policy.speedToleranceMetersPerSecond,
              prediction.lostNormalEnergy.isFinite, prediction.lostNormalEnergy >= 0,
              abs(try a.finite(prediction.lostNormalEnergy-loss)) <= lossLimit,
              abs(try a.finite(prediction.lostNormalEnergy+prediction.retainedNormalEnergy-incoming)) <= lossLimit else { throw JointStopFailure(.invalidSupplierOutput) }
        let n=row.count
        try a.charge(a.product(4,n),&work)
        var impulse=[Double](repeating:0,count:n), velocity=input.state.state.v
        for i in 0..<n { try a.check(policy); impulse[i]=try a.finite(row[i]*normalImpulse) }
        // The final original inverse-mass query owns the actual full generalized velocity jump.
        let delta=try mass.inverse(before,rhs:impulse,prepared:prepared,policy:policy,work:&work)
        for i in 0..<n { try a.check(policy); velocity[i]=try a.finite(velocity[i]+delta[i]) }
        let proposed: KinematicState
        do throws(JointError) { proposed=try KinematicState(revision:input.state.state.revision,time:input.state.state.time,
            q:input.state.state.q,v:velocity,acceleration:[Double](repeating:0,count:n),prescribedAnchors:input.state.state.prescribedAnchors) }
        catch { throw JointStopFailure(.joints(error)) }
        try a.check(policy); try a.treeCharge(input,&work)
        let stateAfter: CompiledKinematicState
        do throws(CompilationFailure) { stateAfter=try input.model.makeState(proposed) }
        catch { throw JointStopFailure(.compilation(error),failedSupplierWorkUnavailable:true) }
        let (sourceAfter,encoderAfter)=try JointStopPreparation.observed(input,state:stateAfter,policy:policy,work:&work)
        try JointStopPreparation.validateEncoder(encoderAfter,input:input,state:stateAfter,layout:prepared.layout,policy:policy,work:&work)
        let after=try JointStopMassInvocation.assemble(prepared,source:sourceAfter,policy:policy,work:&work,loadWork:&loadWork)
        return try JointStopAcceptance.finish(prepared:prepared,side:side,row:row,before:before,after:after,stateAfter:stateAfter,
            sourceAfter:sourceAfter,encoderAfter:encoderAfter,delta:delta,impulse:impulse,normalImpulse:normalImpulse,
            normalBefore:normalRate,w:w,prediction:prediction,policy:policy,work:&work,loadWork:loadWork,contactWork:contactWork)
    }
}
