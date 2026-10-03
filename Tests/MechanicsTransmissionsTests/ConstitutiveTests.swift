import MechanicsCore
import MechanicsConstraints
import MechanicsTransmissions
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConstitutiveTests {
    @Test func shaftPublishesActualInertiaSpringDampingAndAxialAttachment() throws {
        let passive=try ScalarJointLaw(referencePosition:0,stiffness:10,damping:2,coulombEffort:0,minimumPosition:-10,maximumPosition:10)
        let law=try ShaftLaw(rotationalInertia:3,passive:passive)
        var work=try TransmissionFixtures.work(), constraint=try TransmissionFixtures.work()
        let service: any TransmissionConstitutiveEvaluating=PassiveTransmissionEvaluator()
        let result=try service.shaft(TransmissionFixtures.port(0),layout:TransmissionFixtures.layout(1),position:0.3,velocity:0.4,acceleration:0.5,law:law,
            policy:TransmissionFixtures.policy(),work:&work,constraintWork:&constraint)
        #expect(result.inertiaCoefficient == 3); #expect(result.requiredInertialEffort == 1.5)
        #expect(TransmissionFixtures.close(result.kineticEnergy,0.24)); #expect(TransmissionFixtures.close(result.passive.potentialEnergy,0.45))
        #expect(TransmissionFixtures.close(result.passive.smoothEffort,-3.8)); #expect(TransmissionFixtures.close(result.passive.damperPower,-0.32))
        #expect(TransmissionFixtures.close(result.passiveAxialTorque.z,-3.8)); #expect(constraint.operations > 0)
        // Independent inertia power and passive energy rate close the scalar port balance.
        #expect(TransmissionFixtures.close(3*0.4*0.5,result.requiredInertialEffort*0.4))
        #expect(TransmissionFixtures.close(result.passive.smoothEffort*0.4+10*0.3*0.4,result.passive.damperPower))
    }
    @Test func backlashReversalFreeAndClosingOpeningBranchesPreserveAcceptedValue() throws {
        let network=try TransmissionFixtures.compile([TransmissionRelation(id:1,kind:.rigidShaft(first:0,second:1,phase:0,phaseScale:1))])
        let law=try BacklashLaw(id:5,revision:2,halfClearance:0.1,stiffness:100,damping:2,maximumAbsPhase:1,energyScale:1)
        var work=try TransmissionFixtures.work()
        let service: any TransmissionConstitutiveEvaluating=PassiveTransmissionEvaluator()
        let accepted=try service.initializeBacklash(network,rowIndex:0,position:[0.2,0],time:0,law:law,policy:TransmissionFixtures.policy(),work:&work)
        let closing=try service.backlash(network,rowIndex:0,position:[0.2,0],velocity:[0.3,0],time:1,law:law,accepted:accepted,policy:TransmissionFixtures.policy(),work:&work)
        #expect(TransmissionFixtures.close(closing.phaseEffort,-10.6)); #expect(TransmissionFixtures.close(closing.potentialEnergy,0.5))
        #expect(TransmissionFixtures.close(closing.dissipativePower,-0.18)); #expect(TransmissionFixtures.close(closing.mapped.totalPower,-3.18))
        #expect(closing.originalPowerResidual <= 1e-8)
        let opening=try service.backlash(network,rowIndex:0,position:[0.2,0],velocity:[-0.3,0],time:1,law:law,accepted:accepted,policy:TransmissionFixtures.policy(),work:&work)
        #expect(TransmissionFixtures.close(opening.phaseEffort,-10)); #expect(opening.dissipativePower == 0)
        let free=try service.backlash(network,rowIndex:0,position:[0,0],velocity:[-0.3,0],time:2,law:law,accepted:accepted,policy:TransmissionFixtures.policy(),work:&work)
        #expect(free.phaseEffort == 0); #expect(free.potentialEnergy == 0); #expect(free.trial.branch == .free)
        let reverse=try service.backlash(network,rowIndex:0,position:[-0.2,0],velocity:[-0.3,0],time:3,law:law,accepted:accepted,policy:TransmissionFixtures.policy(),work:&work)
        #expect(TransmissionFixtures.close(reverse.phaseEffort,10.6)); #expect(reverse.trial.branch == .negativeFlank)
        #expect(accepted.phase == 0.2); #expect(accepted.time == 0); #expect(accepted.branch == .positiveFlank)
        #expect(TransmissionFixtures.close(accepted.storedEnergy,0.5))
        // Potential derivative is independent of the returned effort implementation.
        let d=1e-6, derivative=(50*(0.2+d-0.1)*(0.2+d-0.1)-50*(0.2-d-0.1)*(0.2-d-0.1))/(2*d)
        #expect(TransmissionFixtures.close(derivative*0.3,closing.potentialRate))
    }
    @Test func directionDependentDragHasNonpositivePowerAndUnselectedStaticEffort() throws {
        let law=try DirectionalDragLaw(positiveViscous:2,negativeViscous:4,positiveCoulomb:3,negativeCoulomb:5,maximumAbsVelocity:10)
        var work=try TransmissionFixtures.work()
        let service: any TransmissionConstitutiveEvaluating=PassiveTransmissionEvaluator(), port=try TransmissionFixtures.port(0), layout=try TransmissionFixtures.layout(1)
        let positive=try service.drag(port,layout:layout,velocity:2,law:law,policy:TransmissionFixtures.policy(),work:&work)
        let negative=try service.drag(port,layout:layout,velocity:-2,law:law,policy:TransmissionFixtures.policy(),work:&work)
        #expect(positive.selectedEffort == -7); #expect(positive.dissipativePower == -14)
        #expect(negative.selectedEffort == 13); #expect(negative.dissipativePower == -26)
        let zero=try service.drag(port,layout:layout,velocity:0,law:law,policy:TransmissionFixtures.policy(),work:&work)
        #expect(zero.selectedEffort == nil)
        switch zero.dryFriction { case .staticInterval(let lower,let upper): #expect(lower == -3); #expect(upper == 5); default: Issue.record("Missing static range.") }
    }
}
