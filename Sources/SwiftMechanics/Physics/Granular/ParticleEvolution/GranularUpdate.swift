internal enum GranularUpdate {
    static func pointVelocity(_ motion: GranularMotion,at point: Vector3) throws(GranularError) -> Vector3 {
        try GranularArithmetic.add(motion.velocity,GranularArithmetic.cross(motion.angularVelocity,GranularArithmetic.sub(point,motion.position)))
    }
    @inline(never)
    static func advance(accepted: GranularState,h: Double,policy: GranularPolicy,workspace: inout GranularWorkspace,work: inout NumericalWork) throws(GranularError) {
        for i in accepted.motions.indices {
            try GranularArithmetic.charge(256,policy:policy,work:&work)
            let old=accepted.motions[i], p=accepted.model.particles[i]
            let v=try GranularArithmetic.add(old.velocity,GranularArithmetic.scale(workspace.forces[i],h/p.mass))
            let w=try GranularArithmetic.add(old.angularVelocity,GranularArithmetic.scale(workspace.torques[i],h/p.momentOfInertia))
            let x=try GranularArithmetic.add(old.position,GranularArithmetic.scale(v,h))
            workspace.motions.append(GranularMotion(position:x,velocity:v,angularVelocity:w))
        }
    }
    @inline(never)
    static func evidence(accepted: GranularState,h: Double,gravity: Vector3,policy: GranularPolicy,workspace: inout GranularWorkspace,work: inout NumericalWork) throws(GranularError) -> GranularStepEvidence {
        var linear=0.0, angular=0.0, energyChange=0.0, midpointWork=0.0, stored=0.0, dissipation=0.0, boundaryWork=0.0
        for i in accepted.motions.indices {
            try GranularArithmetic.charge(1024,policy:policy,work:&work)
            let old=accepted.motions[i], new=workspace.motions[i], p=accepted.model.particles[i]
            let impulse=try GranularArithmetic.scale(workspace.forces[i],h), angularImpulse=try GranularArithmetic.scale(workspace.torques[i],h)
            let residual=try GranularArithmetic.norm(GranularArithmetic.sub(GranularArithmetic.scale(GranularArithmetic.sub(new.velocity,old.velocity),p.mass),impulse))
            let rotational=try GranularArithmetic.norm(GranularArithmetic.sub(GranularArithmetic.scale(GranularArithmetic.sub(new.angularVelocity,old.angularVelocity),p.momentOfInertia),angularImpulse))
            let threshold=try GranularArithmetic.finite(policy.momentumTolerance+policy.relativeTolerance*max(policy.referenceMomentum,GranularArithmetic.norm(impulse)))
            let angularThreshold=try GranularArithmetic.finite(policy.angularMomentumTolerance+policy.relativeTolerance*max(policy.referenceAngularMomentum,GranularArithmetic.norm(angularImpulse)))
            guard residual <= threshold else { throw .residual(value:residual,threshold:threshold) }
            guard rotational <= angularThreshold else { throw .residual(value:rotational,threshold:angularThreshold) }
            linear=max(linear,residual); angular=max(angular,rotational)
            let oldK=try GranularArithmetic.finite(0.5*p.mass*GranularArithmetic.dot(old.velocity,old.velocity)+0.5*p.momentOfInertia*GranularArithmetic.dot(old.angularVelocity,old.angularVelocity))
            let newK=try GranularArithmetic.finite(0.5*p.mass*GranularArithmetic.dot(new.velocity,new.velocity)+0.5*p.momentOfInertia*GranularArithmetic.dot(new.angularVelocity,new.angularVelocity))
            energyChange=try GranularArithmetic.finite(energyChange+newK-oldK)
            let mid=try GranularArithmetic.scale(GranularArithmetic.add(old.velocity,new.velocity),0.5)
            midpointWork=try GranularArithmetic.finite(midpointWork+h*p.mass*GranularArithmetic.dot(gravity,mid))
        }
        // Independently sum each original contact port, rather than reuse assembled force/torque arrays.
        for o in workspace.observations {
            try GranularArithmetic.charge(1024,policy:policy,work:&work)
            let binding=accepted.model.bindings[o.bindingIndex], r=o.response, a=binding.firstParticle
            let va=try midpointPointVelocity(old:accepted.motions[a],new:workspace.motions[a],at:o.point)
            let wa=try GranularArithmetic.scale(GranularArithmetic.add(accepted.motions[a].angularVelocity,workspace.motions[a].angularVelocity),0.5)
            midpointWork=try GranularArithmetic.finite(midpointWork-h*(GranularArithmetic.dot(r.forceOnB,va)+GranularArithmetic.dot(r.coupleOnB,wa)))
            if let b=binding.secondParticle {
                let vb=try midpointPointVelocity(old:accepted.motions[b],new:workspace.motions[b],at:o.point)
                let wb=try GranularArithmetic.scale(GranularArithmetic.add(accepted.motions[b].angularVelocity,workspace.motions[b].angularVelocity),0.5)
                midpointWork=try GranularArithmetic.finite(midpointWork+h*(GranularArithmetic.dot(r.forceOnB,vb)+GranularArithmetic.dot(r.coupleOnB,wb)))
            }
            stored=try GranularArithmetic.finite(stored+r.normalStoredEnergy+r.tangentialStoredEnergy+r.cohesivePotentialEnergy)
            dissipation=try GranularArithmetic.finite(dissipation+h*(r.normalDissipationPower+r.resistanceDissipationPower)+r.tangentialDissipationEnergy)
        }
        for r in workspace.reactions { boundaryWork=try GranularArithmetic.finite(boundaryWork+h*r.prescribedPower) }
        let residual=try GranularArithmetic.finite(abs(energyChange-midpointWork))
        let threshold=try GranularArithmetic.finite(policy.energyTolerance+policy.relativeTolerance*max(policy.referenceEnergy,max(abs(energyChange),abs(midpointWork))))
        guard residual <= threshold else { throw .residual(value:residual,threshold:threshold) }
        return GranularStepEvidence(linear:linear,angular:angular,kineticChange:energyChange,work:midpointWork,workResidual:residual,stored:stored,dissipation:dissipation,boundaryWork:boundaryWork)
    }
    private static func midpointPointVelocity(old: GranularMotion,new: GranularMotion,at point: Vector3) throws(GranularError) -> Vector3 {
        let v=try GranularArithmetic.scale(GranularArithmetic.add(old.velocity,new.velocity),0.5)
        let w=try GranularArithmetic.scale(GranularArithmetic.add(old.angularVelocity,new.angularVelocity),0.5)
        // Frozen port lever arms are measured from the old center, matching the impulse equations.
        return try GranularArithmetic.add(v,GranularArithmetic.cross(w,GranularArithmetic.sub(point,old.position)))
    }
}
