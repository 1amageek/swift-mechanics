import SwiftMechanics
import Testing

@Suite struct ControlPhysicalTests {
    @Test func actualRK4HeldForceAndWork() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (plant,law,policy)=try ControlFixtures.plant(),s=try ControlFixtures.session(plant:plant,law:law,policy:policy)
        defer { _=s.shutdown() }
        let result=try s.step(input:ControlFixtures.input(s,plant:plant)),physical=result.observation.accepted.checkpoint.physical,h=result.observation.controller
        #expect(ControlFixtures.close(physical.q[0],0.0075));#expect(ControlFixtures.close(physical.v[0],0.15));#expect(ControlFixtures.close(physical.acceleration[0],1.5))
        #expect(ControlFixtures.close(h.actuatorIntervalWork,0.0225));#expect(ControlFixtures.close(h.endpointKineticEnergy-h.initialKineticEnergy,0.0225))
        #expect(h.nominalSampledWork == 0);#expect(h.forceResidual < 1e-9);#expect(h.tick == 1 && h.sourceTime == 0 && h.intervalEnd == 0.1)
        #expect(result.integration.acceptedSteps == 1 && result.integration.work.derivativeCalls == 5 && result.integration.work.supplierArithmeticCharged > 0)
    }
    @Test func actualDisturbanceCOMAndNonXAxis() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try ControlFixtures.model(com:Vector3(0.3,-0.2,0.7),axis:.unitY)
        let (plant,law,policy)=try ControlFixtures.plant(model:model,disturbance:-1),s=try ControlFixtures.session(plant:plant,law:law,policy:policy)
        defer { _=s.shutdown() }
        let r=try s.step(input:ControlFixtures.input(s,plant:plant)),h=r.observation.controller,p=r.observation.accepted.checkpoint.physical
        #expect(ControlFixtures.close(p.q[0],0.005));#expect(ControlFixtures.close(p.v[0],0.1))
        #expect(ControlFixtures.close(h.actuatorIntervalWork,0.015));#expect(ControlFixtures.close(h.disturbanceIntervalWork,-0.005));#expect(ControlFixtures.close(h.endpointKineticEnergy,0.01))
    }
    @Test func computedTorqueUsesInverseAndLimits() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (plant,law,policy)=try ControlFixtures.plant(disturbance:-1),s=try ControlFixtures.session(plant:plant,law:law,policy:policy,computed:true)
        defer { _=s.shutdown() }
        let r=try s.step(input:ControlFixtures.input(s,plant:plant,computed:ComputedTorqueReference(positionMeters:0,rateMetersPerSecond:0,accelerationMetersPerSecondSquared:0.7)))
        #expect(ControlFixtures.close(r.observation.controller.heldEffort,2.4));#expect(ControlFixtures.close(r.observation.accepted.checkpoint.physical.q[0],0.0035));#expect(ControlFixtures.close(r.observation.accepted.checkpoint.physical.v[0],0.07))
        let (p2,l2,c2)=try ControlFixtures.plant(disturbance:-1,effort:1.2),s2=try ControlFixtures.session(plant:p2,law:l2,policy:c2,computed:true)
        defer { _=s2.shutdown() }
        let limited=try s2.step(input:ControlFixtures.input(s2,plant:p2,computed:ComputedTorqueReference(positionMeters:0,rateMetersPerSecond:0,accelerationMetersPerSecondSquared:0.7)))
        #expect(ControlFixtures.close(limited.observation.controller.heldEffort,1.2));#expect(limited.observation.controller.clipped)
        #expect(ControlFixtures.close(limited.observation.accepted.checkpoint.physical.acceleration[0],0.1))
    }
    @Test func sampledPositionTrackingMatchesIndependentRecurrence() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (plant,law,policy)=try ControlFixtures.plant(disturbance:-0.2,kp:8,kv:4),s=try ControlFixtures.session(plant:plant,law:law,policy:policy,mode:.position)
        defer { _=s.shutdown() }
        var q=0.0,v=0.0
        for _ in 0..<50 {
            let force=8*(1-q)-4*v,a=(force-0.2)/2
            let r=try s.step(input:ControlFixtures.input(s,plant:plant,value:1,mode:.position))
            q += 0.1*v+0.005*a;v += 0.1*a
            #expect(ControlFixtures.close(r.observation.accepted.checkpoint.physical.q[0],q));#expect(ControlFixtures.close(r.observation.accepted.checkpoint.physical.v[0],v))
        }
        #expect(abs(q-0.975) < 0.01)
    }
    @Test func filterAntiwindupAndRecoveryAreActualServoState() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (plant,law,policy)=try ControlFixtures.plant(kp:4,kv:0,ki:2,effort:1,filter:0.1),s=try ControlFixtures.session(plant:plant,law:law,policy:policy,mode:.position)
        defer { _=s.shutdown() }
        let first=try s.step(input:ControlFixtures.input(s,plant:plant,value:2,mode:.position))
        #expect(first.observation.actuator.secondary == 1);#expect(first.observation.actuator.primary == 0);#expect(first.observation.controller.heldEffort == 1)
        let second=try s.step(input:ControlFixtures.input(s,plant:plant,value:0,mode:.position))
        #expect(ControlFixtures.close(second.observation.actuator.secondary,0.5));#expect(second.observation.actuator.primary == 0)
        let third=try s.step(input:ControlFixtures.input(s,plant:plant,value:-0.5,mode:.position))
        #expect(ControlFixtures.close(third.observation.actuator.secondary,0));#expect(third.observation.actuator.primary < 0)
    }
    @Test func nonDyadicClockEffectiveIntervalsRemainAssociated() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let policy=try ControlFixtures.policy(step:0.03),m=try ControlFixtures.model(time:0.2),parts=try ControlFixtures.plant(model:m,policy:policy)
        let s=try ControlFixtures.session(plant:parts.0,law:parts.1,policy:policy,period:0.03)
        defer { _=s.shutdown() }
        for tick in 1...12 {
            let r=try s.step(input:ControlFixtures.input(s,plant:parts.0,value:0.25)),time=0.2+Double(tick)*0.03
            #expect(r.observation.actuator.time == time);#expect(r.observation.accepted.checkpoint.physical.time == time);#expect(r.observation.controller.intervalEnd == time)
        }
    }
}
