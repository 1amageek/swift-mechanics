internal enum JointStopAcceptance {
    @inline(never)
    static func finish(prepared: PreparedJointStop, side: JointStopSide, row: [Double], before: PhysicalRigidDynamicsSystem,
                       after: PhysicalRigidDynamicsSystem, stateAfter: CompiledKinematicState, sourceAfter: ObservationSource,
                       encoderAfter: JointEncoderObservation, delta: [Double], impulse: [Double], normalImpulse: Double,
                       normalBefore: Double, w: Double, prediction: ContactImpactPrediction, policy: JointStopPolicy,
                       work: inout NumericalWork, loadWork: LoadWork, contactWork: ContactWork) throws(JointStopFailure) -> JointStopImpactResult {
        let a=JointStopArithmetic.self, input=prepared.input, n=row.count, metric=input.definition.metersPerCoordinateUnit
        try a.check(policy); try a.charge(a.sum(128,try a.product(32,n)),&work)
        guard stateAfter.state.q == input.state.state.q, stateAfter.state.time == input.state.state.time,
              stateAfter.stamp == input.state.stamp, encoderAfter.positions == prepared.encoder.positions else { throw JointStopFailure(.staleSource) }
        let sign=side == .lower ? prepared.gaps.lowerJacobian : prepared.gaps.upperJacobian
        let normalAfter=try a.finite(metric*sign*encoderAfter.coordinateRates[0])
        let rowAfter=try a.dot(row,stateAfter.state.v,work:&work)
        let normalResidual=max(abs(try a.finite(normalAfter-prediction.reboundSpeed)),max(abs(try a.finite(normalAfter-rowAfter)),
            abs(try a.finite(normalAfter-normalBefore-w*normalImpulse))))
        guard normalResidual <= policy.speedToleranceMetersPerSecond, normalAfter >= -policy.speedToleranceMetersPerSecond else {
            throw JointStopFailure(.normalRateRejected(value:normalResidual,threshold:policy.speedToleranceMetersPerSecond))
        }
        var original=[Double](repeating:0,count:n)
        do throws(DynamicsError) { try RigidEquationKernel().originalInertialForce(before,acceleration:delta,includeBias:false,into:&original,work:&work) }
        catch { throw JointStopFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var momentum=0.0, momentumScale=0.0
        for i in 0..<n {
            try a.check(policy)
            momentum=max(momentum,abs(try a.finite(original[i]-impulse[i]))/policy.impulseScales[i])
            momentumScale=max(momentumScale,max(abs(original[i]),abs(impulse[i]))/policy.impulseScales[i])
        }
        let momentumLimit=try a.threshold(policy.momentumTolerance,scale:momentumScale)
        guard momentum.isFinite, momentum <= momentumLimit else { throw JointStopFailure(.momentumRejected(value:momentum,threshold:momentumLimit)) }
        let zero=[Double](repeating:0,count:n), energyBefore: MechanicalEnergy, energyAfter: MechanicalEnergy
        do throws(DynamicsError) {
            energyBefore=try RigidEquationKernel().energy(before,acceleration:zero,angularMomentumReference:.zero,requireComplete:true,work:&work)
            energyAfter=try RigidEquationKernel().energy(after,acceleration:zero,angularMomentumReference:.zero,requireComplete:true,work:&work)
        } catch { throw JointStopFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var midpoint=[Double](repeating:0,count:n)
        for i in 0..<n { try a.check(policy); midpoint[i]=try a.finite(0.5*input.state.state.v[i]+0.5*stateAfter.state.v[i]) }
        let generalizedWork=try a.dot(impulse,midpoint,work:&work)
        let normalWork=try a.finite(normalImpulse*(0.5*normalBefore+0.5*normalAfter))
        let change=try a.finite(energyAfter.kineticEnergy-energyBefore.kineticEnergy)
        let workResidual=max(abs(try a.finite(generalizedWork-change)),abs(try a.finite(generalizedWork-normalWork)))
        let energyResidual=max(abs(try a.finite(change+prediction.lostNormalEnergy)),abs(try a.finite(normalWork+prediction.lostNormalEnergy)))
        let energyScale=max(max(abs(energyBefore.kineticEnergy),abs(energyAfter.kineticEnergy)),max(abs(generalizedWork),prediction.lostNormalEnergy))
        let energyLimit=try a.threshold(policy.energyToleranceJoules,scale:energyScale)
        guard workResidual <= energyLimit else { throw JointStopFailure(.workRejected(value:workResidual,threshold:energyLimit)) }
        guard energyBefore.kineticEnergy >= -energyLimit, energyAfter.kineticEnergy >= -energyLimit,
              change <= energyLimit, energyResidual <= energyLimit else { throw JointStopFailure(.energyRejected(value:energyResidual,threshold:energyLimit)) }
        let coordinateImpulse=try a.finite(metric*normalImpulse)
        let unit: PhysicalDimension=input.definition.coordinateUnit == .length ? PhysicalDimension(length:1,mass:1,time:-1) : PhysicalDimension(length:2,mass:1,time:-1,angle:-1)
        try a.check(policy)
        guard !loadWork.budget.isCancelled() else { throw JointStopFailure(.loads(.cancelled)) }
        let diagnostics=JointStopDiagnostics(effectiveInverseMassPerKilogram:w,normalSpeedBeforeMetersPerSecond:normalBefore,
            normalSpeedAfterMetersPerSecond:normalAfter,normalRateResidualMetersPerSecond:normalResidual,normalizedMomentumResidual:momentum,
            normalLossJoules:prediction.lostNormalEnergy,generalizedImpulseWorkJoules:generalizedWork,normalImpulseWorkJoules:normalWork,
            workResidualJoules:workResidual,energyResidualJoules:energyResidual,numericalWork:work,loadWork:loadWork,contactWork:contactWork)
        return JointStopImpactResult(prepared:prepared,side:side,stateAfter:stateAfter,sourceAfter:sourceAfter,encoderAfter:encoderAfter,
            physicalBefore:before,physicalAfter:after,energyBefore:energyBefore,energyAfter:energyAfter,velocityJump:delta,generalizedImpulse:impulse,
            normalImpulseNewtonSeconds:normalImpulse,coordinateImpulse:coordinateImpulse,coordinateImpulseUnit:unit,diagnostics:diagnostics)
    }
}
