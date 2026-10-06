internal enum FrictionalImpulseAcceptance {
    @inline(never)
    static func finish(source: FrictionalImpulseSource, before: PhysicalRigidDynamicsSystem, after: PhysicalRigidDynamicsSystem,
                       state: KinematicState, snapshot: KinematicSnapshot, w: [Double], impulse: [Double], delta: [Double],
                       applied: [Double], tangent: FrictionalImpulseTangent, prediction: ContactImpactPrediction,
                       policy: FrictionalImpulsePolicy, work: inout NumericalWork, loadWork: LoadWork,
                       contactWork: ContactWork) throws(FrictionalImpulseFailure) -> FrictionalImpulseResult {
        let a=FrictionalImpulseArithmetic.self, h=policy.hybrid, input=source.input, n=state.v.count
        try a.check(policy); try a.charge(a.sum(2048,try a.product(256,n)),&work)
        let calculator=KinematicJacobianCalculator()
        let first=try a.source { try calculator.pointMotion(body:source.first.body,bodyLocalPoint:source.firstLocal,snapshot:snapshot) }
        let second=try a.source { try calculator.pointMotion(body:source.second.body,bodyLocalPoint:source.secondLocal,snapshot:snapshot) }
        guard try a.core({ () throws(CoreError) in try first.position.subtracting(input.contact.witness.pointA).magnitude() }) <= h.lengthTolerance,
              try a.core({ () throws(CoreError) in try second.position.subtracting(input.contact.witness.pointB).magnitude() }) <= h.lengthTolerance else { throw FrictionalImpulseFailure(.stalePose) }
        let velocity=try a.components(a.core { () throws(CoreError) in try second.velocity.subtracting(first.velocity) },basis:input.basis)
        let drift=try a.components(a.core { () throws(CoreError) in try second.prescribedDriftVelocity.subtracting(first.prescribedDriftVelocity) },basis:input.basis)
        var velocityResidual=0.0
        for row in 0..<3 {
            var expected=source.before[row]
            for column in 0..<3 { expected=try a.finite(expected+w[row*3+column]*impulse[column]) }
            velocityResidual=max(velocityResidual,abs(try a.finite(expected-velocity[row])))
            velocityResidual=max(velocityResidual,abs(try a.finite(drift[row]-source.drift[row])))
        }
        velocityResidual=max(velocityResidual,abs(try a.finite(velocity[0]-prediction.reboundSpeed)))
        guard velocityResidual <= h.speedTolerance, velocity[0] >= -h.speedTolerance else { throw FrictionalImpulseFailure(.velocityRejected(value:velocityResidual,threshold:h.speedTolerance)) }
        let tangentNorm=try a.norm([impulse[1],impulse[2]]), radius=try a.finite(policy.coefficient*impulse[0])
        let impulseScale=policy.massScaleKg*policy.velocityScale
        let coneLimit=try a.finite(impulseScale*a.threshold(policy.impulseTolerance,scale:radius/impulseScale))
        var coulombResidual=max(0,try a.finite(tangentNorm-radius))
        let tangentSpeed=try a.norm([velocity[1],velocity[2]])
        switch tangent.regime {
        case .frictionless:
            guard policy.coefficient == 0, tangentNorm == 0 else { throw FrictionalImpulseFailure(.invalidSupplierOutput) }
        case .sticking:
            guard tangentNorm < radius, tangentSpeed <= h.speedTolerance else { throw FrictionalImpulseFailure(.velocityRejected(value:tangentSpeed,threshold:h.speedTolerance)) }
        case .sliding:
            coulombResidual=max(coulombResidual,abs(try a.finite(tangentNorm-radius)))
            // FIXME(INCOMPLETE_IMPLEMENTATION): A speed-sized sliding/sticking tie reaches returned-row acceptance.
            // A separately specified limiting regime law must be physically verified before this tie succeeds.
            guard tangentSpeed > h.speedTolerance else { throw FrictionalImpulseFailure(.ambiguousBoundary) }
            // Physical returned tangent rows own the nonassociated Coulomb direction.
            coulombResidual=max(coulombResidual,try a.norm([
                try a.finite(impulse[1]+radius*(velocity[1]/tangentSpeed)),
                try a.finite(impulse[2]+radius*(velocity[2]/tangentSpeed))]))
        }
        guard coulombResidual <= coneLimit else { throw FrictionalImpulseFailure(.coulombRejected(value:coulombResidual,threshold:coneLimit)) }
        var original=[Double](repeating:0,count:n)
        do { try RigidEquationKernel().originalInertialForce(before,acceleration:delta,includeBias:false,into:&original,work:&work) }
        catch { throw FrictionalImpulseFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var momentum=0.0, momentumScale=0.0
        for i in 0..<n {
            momentum=max(momentum,abs(try a.finite(original[i]-applied[i]))/h.impulseScales[i])
            momentumScale=max(momentumScale,max(abs(original[i]),abs(applied[i]))/h.impulseScales[i])
        }
        let worldImpulse=try a.core { () throws(CoreError) in try input.basis.normal.scaled(by:impulse[0])
            .adding(input.basis.firstTangent.scaled(by:impulse[1])).adding(input.basis.secondTangent.scaled(by:impulse[2])) }
        let firstImpulse: FramedImpulse, secondImpulse: FramedImpulse, firstOrigin: SpatialWrench, secondOrigin: SpatialWrench
        let firstBody=try a.source { try source.snapshot.body(source.first.body) }, secondBody=try a.source { try source.snapshot.body(source.second.body) }
        do {
            firstImpulse=try FramedImpulse(body:source.first.body,frame:input.tree.worldFrame,point:input.contact.witness.pointA,
                impulse:a.core { () throws(CoreError) in try worldImpulse.scaled(by:-1) })
            secondImpulse=try FramedImpulse(body:source.second.body,frame:input.tree.worldFrame,point:input.contact.witness.pointB,impulse:worldImpulse)
            firstOrigin=try firstImpulse.equivalent(about:firstBody.motion.pose.translation)
            secondOrigin=try secondImpulse.equivalent(about:secondBody.motion.pose.translation)
        } catch let error as LoadError { throw FrictionalImpulseFailure(.loads(error)) }
        catch let failure as FrictionalImpulseFailure { throw failure }
        catch { throw FrictionalImpulseFailure(.unexpectedSupplierFailure) }
        // Reproject the actual physical point impulse pair through body-origin geometric columns.
        let firstColumns=try a.source { try source.snapshot.geometricColumns(body:source.first.body) }
        let secondColumns=try a.source { try source.snapshot.geometricColumns(body:source.second.body) }
        for i in 0..<n {
            let ca=firstColumns[firstColumns.startIndex+i], cb=secondColumns[secondColumns.startIndex+i]
            let physical=try a.core { () throws(CoreError) in try firstOrigin.torque.dot(ca.angular)+firstOrigin.force.dot(ca.linear)
                + secondOrigin.torque.dot(cb.angular)+secondOrigin.force.dot(cb.linear) }
            momentum=max(momentum,abs(try a.finite(physical-applied[i]))/h.impulseScales[i])
            momentumScale=max(momentumScale,max(abs(physical),abs(applied[i]))/h.impulseScales[i])
        }
        let momentumLimit=try a.finite(h.momentumAbsolute+h.momentumRelative*momentumScale)
        guard momentum <= momentumLimit else { throw FrictionalImpulseFailure(.momentumRejected(value:momentum,threshold:momentumLimit)) }
        let zero=[Double](repeating:0,count:n), energyBefore: MechanicalEnergy, energyAfter: MechanicalEnergy
        do {
            energyBefore=try RigidEquationKernel().energy(before,acceleration:zero,angularMomentumReference:.zero,requireComplete:true,work:&work)
            energyAfter=try RigidEquationKernel().energy(after,acceleration:zero,angularMomentumReference:.zero,requireComplete:true,work:&work)
        } catch { throw FrictionalImpulseFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var midpoint=[Double](repeating:0,count:n)
        for i in 0..<n { midpoint[i]=try a.finite(0.5*input.state.v[i]+0.5*state.v[i]) }
        let generalizedWork=try a.dot(applied,midpoint,work:&work)
        var contactWorkValue=0.0, driftWork=0.0
        for i in 0..<3 {
            contactWorkValue=try a.finite(contactWorkValue+impulse[i]*(0.5*source.before[i]+0.5*velocity[i]))
            driftWork=try a.finite(driftWork+impulse[i]*source.drift[i])
        }
        let wallWork=try a.finite(-driftWork)
        let tangentLoss=try a.finite(-(source.before[1]*impulse[1]+source.before[2]*impulse[2]
            + 0.5*impulse[1]*(w[4]*impulse[1]+w[5]*impulse[2])+0.5*impulse[2]*(w[7]*impulse[1]+w[8]*impulse[2])))
        let loss=try a.finite(prediction.lostNormalEnergy+tangentLoss)
        let kineticChange=try a.finite(energyAfter.kineticEnergy-energyBefore.kineticEnergy)
        let firstAfter=try a.source { try snapshot.body(source.first.body) }, secondAfter=try a.source { try snapshot.body(source.second.body) }
        func midpointWork(_ wrench: SpatialWrench, _ minus: SpatialMotion, _ plus: SpatialMotion) throws(FrictionalImpulseFailure) -> Double {
            try a.core { () throws(CoreError) in
                let angular=try minus.angular.scaled(by:0.5).adding(plus.angular.scaled(by:0.5))
                let linear=try minus.linear.scaled(by:0.5).adding(plus.linear.scaled(by:0.5))
                return try wrench.torque.dot(angular)+wrench.force.dot(linear)
            }
        }
        let physicalWork=try a.finite(midpointWork(firstOrigin,firstBody.motion.velocity,firstAfter.motion.velocity)
            + midpointWork(secondOrigin,secondBody.motion.velocity,secondAfter.motion.velocity))
        let workResidual=max(abs(try a.finite(contactWorkValue-physicalWork)),max(abs(try a.finite(contactWorkValue-generalizedWork-driftWork)),abs(try a.finite(kineticChange-generalizedWork))))
        let energyResidual=max(abs(try a.finite(kineticChange+loss-wallWork)),abs(try a.finite(contactWorkValue+loss)))
        let energyScale=max(max(abs(energyBefore.kineticEnergy),abs(energyAfter.kineticEnergy)),max(abs(loss),max(abs(contactWorkValue),abs(wallWork))))
        let energyLimit=try a.finite(h.energyAbsolute+h.energyRelative*energyScale)
        guard workResidual <= energyLimit else { throw FrictionalImpulseFailure(.workRejected(value:workResidual,threshold:energyLimit)) }
        guard tangentLoss >= -energyLimit, energyBefore.kineticEnergy >= -h.energyAbsolute,
              energyAfter.kineticEnergy >= -h.energyAbsolute, energyResidual <= energyLimit else { throw FrictionalImpulseFailure(.energyRejected(value:energyResidual,threshold:energyLimit)) }
        try a.check(policy)
        guard !loadWork.budget.isCancelled() else { throw FrictionalImpulseFailure(.loads(.cancelled)) }
        let diagnostics=FrictionalImpulseDiagnostics(delassus:w,tangentMultiplier:tangent.multiplier,momentumResidual:momentum,
            velocityResidual:velocityResidual,coulombResidual:coulombResidual,workResidual:workResidual,energyResidual:energyResidual,
            generalizedImpulseWorkJoules:generalizedWork,contactImpulseWorkJoules:contactWorkValue,prescribedWallWorkJoules:wallWork,
            normalLossJoules:prediction.lostNormalEnergy,tangentLossJoules:tangentLoss,numericalWork:work,loadWork:loadWork,contactWork:contactWork)
        return FrictionalImpulseResult(input:input,stateAfter:state,snapshotAfter:snapshot,physicalBefore:before,physicalAfter:after,
            regime:tangent.regime,impulse:try a.vector(impulse),relativeVelocityBefore:try a.vector(source.before),relativeVelocityAfter:try a.vector(velocity),
            firstImpulse:firstImpulse,secondImpulse:secondImpulse,firstOriginImpulse:firstOrigin,secondOriginImpulse:secondOrigin,
            energyBefore:energyBefore,energyAfter:energyAfter,diagnostics:diagnostics)
    }
}
