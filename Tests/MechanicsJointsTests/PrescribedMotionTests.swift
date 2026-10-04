import Foundation
import SwiftMechanics
import Testing

@Suite struct PrescribedMotionTests {
    private func programme() throws -> PrescribedMotionProgram {
        let policy=try PrescribedMotionPolicy(maximumSamples:2,maximumIdentifierBytes:100,maximumMetadataBytes:2000)
        let motion=try AnalyticPrescribedMotion(frame:EntityID(kind:.frame,key:"anchor"),parentFrame:EntityID(kind:.frame,key:"parent"),referenceTime:1,
            initialPose:RigidTransform(rotation:UnitQuaternion(axis:.unitX,angle:0.7).negated(),translation:Vector3(2,-1,0)),
            translationRate:Vector3(0.2,0.3,0),translationAcceleration:Vector3(0.4,-0.2,0),rotationAxis:.unitZ,
            angularRate:0.5,angularAcceleration:0.3,minimumTime:0,maximumTime:3,maximumIdentifierBytes:100)
        var work=NumericalWork(budget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:10))
        return try PrescribedMotionProgram(motions:[motion],policy:policy,work:&work)
    }
    @Test func analyticPoseAndMovingOriginDerivativesAreOriginal() throws {
        let program=try programme();var work=NumericalWork(budget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:10))
        let sampler:any PrescribedMotionSampling=AnalyticPrescribedMotionSampler()
        let initial=try sampler.sample(program,time:1,policy:program.policy,work:&work)
        #expect(initial.anchors[0].motion.pose == program.motions[0].initialPose)
        #expect(initial.anchors[0].motion.pose.rotation.w.bitPattern == program.motions[0].initialPose.rotation.w.bitPattern)
        let value=try sampler.sample(program,time:2,policy:program.policy,work:&work),m=value.anchors[0].motion
        #expect(abs(m.pose.translation.x-2.4) < 1e-14);#expect(abs(m.pose.translation.y+0.8) < 1e-14)
        #expect(abs(m.velocity.linear.x-0.6) < 1e-14);#expect(abs(m.velocity.linear.y-0.1) < 1e-14)
        #expect(m.acceleration.linear == program.motions[0].translationAcceleration)
        #expect(abs(m.velocity.angular.z-0.8) < 1e-14);#expect(abs(m.acceleration.angular.z-0.3) < 1e-14)
        let direction=try m.pose.rotation.rotating(.unitY)
        #expect(abs(direction.x+sin(0.65)*cos(0.7)) < 1e-14)
        #expect(abs(direction.y-cos(0.65)*cos(0.7)) < 1e-14);#expect(abs(direction.z-sin(0.7)) < 1e-14)
        let accepted=try OriginalPrescribedMotionAcceptance.validated(value,program:program,time:2,policy:program.policy,work:&work)
        #expect(accepted.anchors == value.anchors);#expect(work.operations > 0)
    }
    @Test func domainCapacityAndSameTimeWrongPhysicalSamplesFail() throws {
        let program=try programme();var work=NumericalWork(budget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:10))
        let actual=try AnalyticPrescribedMotionSampler().sample(program,time:2,policy:program.policy,work:&work)
        let wrong=try PrescribedAnchorState(frame:actual.anchors[0].frame,time:2,motion:.stationary(pose:.identity))
        let supplied=try PrescribedMotionSample(metadata:program.metadata,time:2,anchors:[wrong],policy:program.policy)
        do throws(PrescribedMotionError) { _=try OriginalPrescribedMotionAcceptance.validated(supplied,program:program,time:2,policy:program.policy,work:&work);Issue.record("Wrong law sample accepted") }
        catch { if case .staleSource=error {} else { Issue.record("Unexpected law failure") } }
        do throws(PrescribedMotionError) { _=try AnalyticPrescribedMotionSampler().sample(program,time:3.01,policy:program.policy,work:&work);Issue.record("Interval extrapolated") }
        catch { if case .outsideDomain=error {} else { Issue.record("Unexpected interval failure") } }
        let small=try PrescribedMotionPolicy(maximumSamples:2,maximumIdentifierBytes:100,maximumMetadataBytes:20)
        do throws(PrescribedMotionError) { _=try PrescribedMotionProgram(motions:program.motions,policy:small,work:&work);Issue.record("Metadata capacity ignored") }
        catch { if case .capacityExceeded=error {} else { Issue.record("Unexpected capacity failure") } }
    }
}
