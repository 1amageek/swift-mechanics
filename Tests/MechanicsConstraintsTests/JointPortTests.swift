import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct JointPortTests {
    @Test func scalarSpringDamperAndSlidingPowerMatchEnergyDerivative() throws {
        let joint=try JointManifold(.revolute(axis:.unitZ))
        let law=try ScalarJointLaw(referencePosition:0.2,stiffness:10,damping:3,coulombEffort:2,minimumPosition:-10,maximumPosition:10)
        var work=try ConstraintFixtures.work()
        let evaluator: any ScalarJointPortEvaluating=ScalarJointPortEvaluator()
        let result=try evaluator.passive(joint,position:0.7,velocity:-0.4,law:law,wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work)
        #expect(ConstraintFixtures.close(result.smoothEffort,-3.8)); #expect(ConstraintFixtures.close(result.potentialEnergy,1.25))
        #expect(ConstraintFixtures.close(result.damperPower,-0.48)); #expect(result.coordinateDimension == .angle)
        switch result.friction { case .sliding(let effort,let power): #expect(effort == 2); #expect(power == -0.8); default: Issue.record("Expected sliding law.") }
        let d=1e-5, plus=0.5*10*(0.7+d-0.2)*(0.7+d-0.2), minus=0.5*10*(0.7-d-0.2)*(0.7-d-0.2)
        #expect(ConstraintFixtures.close(-(plus-minus)/(2*d)-3 * -0.4,result.smoothEffort))
    }
    @Test func zeroSpeedFrictionRemainsSetValued() throws {
        let joint=try JointManifold(.prismatic(axis:.unitX)), law=try ScalarJointLaw(referencePosition:0,stiffness:1,damping:1,coulombEffort:3,minimumPosition:-1,maximumPosition:1)
        var work=try ConstraintFixtures.work()
        let result=try ScalarJointPortEvaluator().passive(joint,position:0.2,velocity:0,law:law,wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work)
        switch result.friction { case .staticInterval(let lower,let upper): #expect(lower == -3); #expect(upper == 3); default: Issue.record("Static effort must not be selected without dynamics.") }
        #expect(result.smoothEffort == -0.2)
    }
    @Test func bothLimitSidesHaveSignedRowsAndCompliantDissipation() throws {
        let joint=try JointManifold(.prismatic(axis:.unitX)), evaluator: any ScalarJointPortEvaluating=ScalarJointPortEvaluator()
        for sign in [-1.0,1.0] {
            var work=try ConstraintFixtures.work()
            let result=try evaluator.limits(joint,position:sign*1.2,velocity:sign*0.5,lower:-1,upper:1,mode:.compliant(stiffness:100,damping:4),impact:.none,wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work)
            #expect(ConstraintFixtures.close(result.compliantEffort ?? .nan,-sign*22))
            #expect(ConstraintFixtures.close(result.potentialEnergy ?? .nan,2)); #expect(result.dissipativePower == -1)
            #expect(result.lowerJacobian == 1); #expect(result.upperJacobian == -1)
        }
        var work=try ConstraintFixtures.work()
        let hard=try evaluator.limits(joint,position:0,velocity:1,lower:-1,upper:1,mode:.rowsOnly,impact:.none,wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work)
        #expect(hard.compliantEffort == nil); #expect(hard.potentialEnergy == nil)
    }
}
