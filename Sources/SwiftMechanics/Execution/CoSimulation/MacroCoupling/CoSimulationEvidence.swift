internal enum CoSimulationEvidence {
    static func agrees(_ a: Double, _ b: Double, _ tolerance: NumericalTolerance) -> Bool {
        let error=abs(a-b), threshold=tolerance.absolute+tolerance.relative*max(abs(a),abs(b))
        return a.isFinite && b.isFinite && error.isFinite && threshold.isFinite && error <= threshold
    }
    static func nonpositive(_ value: Double, _ tolerance: NumericalTolerance) -> Bool {
        let threshold=tolerance.absolute+tolerance.relative*abs(value)
        return value.isFinite && threshold.isFinite && value <= threshold
    }
    static func heldForce(_ boundary: CoSimulationBoundary, coupling: CoSimulationCoupling) throws(CoSimulationFailure) -> Double {
        let a=boundary.first.accepted.checkpoint.physical, b=boundary.second.accepted.checkpoint.physical
        guard a.q.count == 1, b.q.count == 1, a.v.count == 1, b.v.count == 1 else { throw .refusal(.originalEvidenceRejected) }
        let extensionMeters=b.q[0]-a.q[0]-coupling.restOffsetMeters
        let relativeRate=b.v[0]-a.v[0]
        let force=coupling.stiffnessNewtonsPerMeter*extensionMeters+coupling.dampingNewtonSecondsPerMeter*relativeRate
        guard extensionMeters.isFinite, relativeRate.isFinite, force.isFinite else { throw .refusal(.originalEvidenceRejected) }
        return force
    }
    private static func participant(_ result: ControlStepResult, source: ControlObservation,
                                    configuration: CoSimulationParticipantConfiguration, force: Double,
                                    coupling: CoSimulationCoupling) throws(CoSimulationFailure) {
        let h=result.observation.controller, dt=h.intervalEnd-h.sourceTime
        let delta=h.endpointPosition-source.accepted.checkpoint.physical.q[0]
        let actuator=force*delta, external=configuration.plant.disturbanceNewtons*delta
        let kinetic=h.endpointKineticEnergy-h.initialKineticEnergy
        let forceThreshold=coupling.forceAgreement.absolute+coupling.forceAgreement.relative*abs(force+configuration.plant.disturbanceNewtons)
        guard dt.isFinite, dt > 0, delta.isFinite, h.initialKineticEnergy.isFinite, h.initialKineticEnergy >= 0,
              h.endpointKineticEnergy.isFinite, h.endpointKineticEnergy >= 0,
              agrees(h.actuatorIntervalWork,actuator,coupling.energyAgreement),
              agrees(h.disturbanceIntervalWork,external,coupling.energyAgreement),
              agrees(kinetic,actuator+external,coupling.energyAgreement),
              h.forceResidual.isFinite, forceThreshold.isFinite, abs(h.forceResidual) <= forceThreshold else { throw .refusal(.originalEvidenceRejected) }
        if source.controller.issued {
            guard agrees(source.controller.endpointKineticEnergy,h.initialKineticEnergy,coupling.energyAgreement)
                else { throw .refusal(.originalEvidenceRejected) }
        }
    }
    static func receipt(source: CoSimulationBoundary, first: ControlStepResult, second: ControlStepResult,
                        firstConfiguration: CoSimulationParticipantConfiguration, secondConfiguration: CoSimulationParticipantConfiguration,
                        coupling: CoSimulationCoupling, force: Double, work: CoSimulationWorkLedger) throws(CoSimulationFailure) -> CoSimulationMacroReceipt {
        try participant(first,source:source.first,configuration:firstConfiguration,force:force,coupling:coupling)
        try participant(second,source:source.second,configuration:secondConfiguration,force:-force,coupling:coupling)
        let a=source.first.accepted.checkpoint.physical, b=source.second.accepted.checkpoint.physical
        let x=first.observation.accepted.checkpoint.physical, y=second.observation.accepted.checkpoint.physical
        guard x.time == y.time, a.time == b.time, first.observation.controller.tick == second.observation.controller.tick else { throw .refusal(.staleBoundary) }
        let dt=x.time-a.time, e0=b.q[0]-a.q[0]-coupling.restOffsetMeters, e1=y.q[0]-x.q[0]-coupling.restOffsetMeters
        let r0=b.v[0]-a.v[0], r1=y.v[0]-x.v[0], k=coupling.stiffnessNewtonsPerMeter, d=coupling.dampingNewtonSecondsPerMeter
        let u0=0.5*k*e0*e0, u1=0.5*k*e1*e1, spring=u1-u0
        let exchanged=force*(x.q[0]-a.q[0])-force*(y.q[0]-b.q[0])
        // The real admitted plant has constant scalar acceleration over this held-force interval.
        // This is the continuous damping oracle along its actual linear velocity trajectory.
        let damping=d*dt*(r0*r0+r0*r1+r1*r1)/3
        let defect=exchanged+spring+damping
        let startPower=force*a.v[0]-force*b.v[0], endPower=force*x.v[0]-force*y.v[0], meanPower=exchanged/dt
        let external=first.observation.controller.disturbanceIntervalWork+second.observation.controller.disturbanceIntervalWork
        let accumulated=source.accumulatedAbsoluteEnergyDefectJoules+abs(defect)
        let threshold=coupling.energyAgreement.absolute+coupling.energyAgreement.relative*max(abs(exchanged),max(abs(spring),abs(damping)))
        guard dt.isFinite, dt > 0, u0.isFinite, u1.isFinite, u0 >= 0, u1 >= 0,
              damping.isFinite, damping >= 0, spring.isFinite, defect.isFinite, exchanged.isFinite, external.isFinite,
              startPower.isFinite, endPower.isFinite, meanPower.isFinite, threshold.isFinite, abs(defect) <= threshold,
              accumulated.isFinite, accumulated <= coupling.maximumAccumulatedAbsoluteEnergyDefectJoules,
              agrees(exchanged,first.observation.controller.actuatorIntervalWork+second.observation.controller.actuatorIntervalWork,coupling.energyAgreement)
              else { throw .refusal(.originalEvidenceRejected) }
        if k == 0 {
            guard nonpositive(exchanged,coupling.energyAgreement), nonpositive(startPower,coupling.powerAgreement),
                  nonpositive(endPower,coupling.powerAgreement) else { throw .refusal(.originalEvidenceRejected) }
        }
        let boundary=CoSimulationBoundary(first:first.observation,second:second.observation,work:work,defect:accumulated)
        return CoSimulationMacroReceipt(boundary:boundary,first:first,second:second,force:force,work:exchanged,
            disturbance:external,spring:spring,damping:damping,defect:defect,startPower:startPower,endPower:endPower,meanPower:meanPower)
    }
}
