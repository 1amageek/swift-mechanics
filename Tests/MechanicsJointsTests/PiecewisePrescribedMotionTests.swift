import Foundation
import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PiecewisePrescribedMotionTests {
    @Test func quinticSegmentsRecoverIndependentPolynomialsAtInteriorAndExactEndpoints() throws {
        for duration in [0.5,1.0,2.0] {
            let law = try PrescribedTrajectoryFixtures.piecewise(duration: duration)
            let program = try PrescribedTrajectoryFixtures.anchor([.piecewise(law)])
            var work = try PrescribedTrajectoryFixtures.work()
            for fraction in [0.0,0.23,0.9,1,1.01,1.43,2] {
                let t = duration*fraction
                let result = try AnalyticPrescribedTrajectorySampler().sample(program,time: t,policy: program.policy,work: &work).anchors[0].motion
                let x = PrescribedTrajectoryFixtures.polynomial(t,duration: duration)
                #expect(abs(result.pose.translation.x-(1+x.p)) < 3e-13)
                #expect(abs(result.pose.translation.y-(2-0.5*x.p)) < 3e-13)
                #expect(abs(result.velocity.linear.x-x.v) < 3e-13)
                #expect(abs(result.acceleration.linear.x-x.a) < 3e-12)
                #expect(abs(result.velocity.angular.z-2*x.v) < 3e-13)
                #expect(abs(result.acceleration.angular.z-2*x.a) < 3e-12)
                let rotation = result.pose.rotation, angle = 2*x.p
                for (actual,expected) in zip([rotation.w,rotation.x,rotation.y,rotation.z],
                    [cos(angle/2)*cos(0.2),cos(angle/2)*sin(0.2),sin(angle/2)*sin(0.2),sin(angle/2)*cos(0.2)]) { #expect(abs(actual-expected) < 3e-14) }
                if fraction == 1 { #expect(result.velocity.linear == law.segments[1].start.linearVelocity);#expect(result.acceleration.linear == law.segments[1].start.linearAcceleration) }
                if fraction == 2 { #expect(result.velocity.linear == law.segments[1].end.linearVelocity);#expect(result.acceleration.linear == law.segments[1].end.linearAcceleration) }
            }
            let h = duration*1e-5, t = duration*1.43
            let before = try AnalyticPrescribedTrajectorySampler().sample(program,time: t-h,policy: program.policy,work: &work).anchors[0].motion
            let after = try AnalyticPrescribedTrajectorySampler().sample(program,time: t+h,policy: program.policy,work: &work).anchors[0].motion
            let x = PrescribedTrajectoryFixtures.polynomial(t,duration: duration)
            #expect(abs((after.pose.translation.x-before.pose.translation.x)/(2*h)-x.v) < 5e-9/duration)
            #expect(abs((after.velocity.linear.x-before.velocity.linear.x)/(2*h)-x.a) < 5e-9/(duration*duration))
        }
    }

    @Test func exactRightKnotUsesFollowingSignedZeroJetAndFinalUsesLeftJet() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(planar: true)
        let seam = law.segments[1].start
        let right = try PrescribedMotionJet(displacement: seam.displacement,angle: seam.angle,linearVelocity: seam.linearVelocity,
            angularRate: seam.angularRate,linearAcceleration: Vector3(seam.linearAcceleration.x,seam.linearAcceleration.y,-0.0),angularAcceleration: seam.angularAcceleration)
        let second = try PrescribedMotionSegment(startTime: 1,endTime: 2,start: right,end: law.segments[1].end)
        let policy = try PrescribedTrajectoryFixtures.policy()
        var work = try PrescribedTrajectoryFixtures.work()
        let changed = try PiecewisePrescribedMotion(frame: law.frame,parentFrame: law.parentFrame,initialPose: law.initialPose,rotationAxis: law.rotationAxis,
            segments: [law.segments[0],second],policy: policy,work: &work)
        let program = try PrescribedTrajectoryFixtures.anchor([.piecewise(changed)])
        let result = try AnalyticPrescribedTrajectorySampler().sample(program,time: 1,policy: policy,work: &work)
        #expect(result.anchors[0].motion.acceleration.linear.z.bitPattern == (-0.0).bitPattern)
        let old = try PrescribedTrajectoryFixtures.anchor([.piecewise(law)])
        #expect(program.metadata != old.metadata)
        let final = try AnalyticPrescribedTrajectorySampler().sample(program,time: 2,policy: policy,work: &work)
        #expect(final.anchors[0].motion.acceleration.linear.z.bitPattern == law.segments[1].end.linearAcceleration.z.bitPattern)
    }

    @Test func firstBrokenDerivativeIsTypedAndNoImplicitEventIsCreated() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(), policy = try PrescribedTrajectoryFixtures.policy()
        for derivative in [PrescribedTrajectoryDerivative.position,.velocity,.acceleration] {
            let seam = law.segments[1].start
            let changed = try PrescribedMotionJet(displacement: seam.displacement,angle: seam.angle+(derivative == .position ? 2*Double.pi : 0),
                linearVelocity: seam.linearVelocity,angularRate: seam.angularRate+(derivative == .velocity ? 1 : 0),
                linearAcceleration: seam.linearAcceleration,angularAcceleration: seam.angularAcceleration+(derivative == .acceleration ? 1 : 0))
            let second = try PrescribedMotionSegment(startTime: 1,endTime: 2,start: changed,end: law.segments[1].end)
            var work = try PrescribedTrajectoryFixtures.work()
            do throws(PrescribedMotionError) {
                _ = try PiecewisePrescribedMotion(frame: law.frame,parentFrame: law.parentFrame,initialPose: law.initialPose,rotationAxis: law.rotationAxis,
                    segments: [law.segments[0],second],policy: policy,work: &work)
                Issue.record("Discontinuity accepted as a smooth trajectory")
            } catch {
                if case .unsupportedDiscontinuity(let time,let actual) = error { #expect(time == 1 && actual == derivative && work.operations > 0) }
                else { Issue.record("Wrong discontinuity refusal") }
            }
        }
    }

    @Test func invalidSegmentInventoryAndUnrepresentableInterpolationAreRefused() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(), policy = try PrescribedTrajectoryFixtures.policy()
        let zero = try PrescribedTrajectoryFixtures.jet(0)
        let end = try PrescribedTrajectoryFixtures.jet(2)
        let gap = try PrescribedMotionSegment(startTime: 1.1,endTime: 2,start: law.segments[1].start,end: end)
        let huge = try PrescribedMotionJet(displacement: Vector3(Double.greatestFiniteMagnitude,0,0),angle: 0,
            linearVelocity: .zero,angularRate: 0,linearAcceleration: .zero,angularAcceleration: 0)
        let overflow = try PrescribedMotionSegment(startTime: 0,endTime: 1,start: zero,end: huge)
        for segments in [[PrescribedMotionSegment](),[law.segments[0],gap],[law.segments[1],law.segments[0]],[overflow]] {
            var work = try PrescribedTrajectoryFixtures.work()
            do throws(PrescribedMotionError) {
                _ = try PiecewisePrescribedMotion(frame: law.frame,parentFrame: law.parentFrame,initialPose: law.initialPose,rotationAxis: law.rotationAxis,
                    segments: segments,policy: policy,work: &work)
                Issue.record("Invalid inventory or polynomial admitted")
            } catch {
                switch error { case .capacityExceeded: #expect(segments.isEmpty);case .invalidInput: #expect(!segments.isEmpty);default: Issue.record("Wrong mathematical refusal: \(error)") }
            }
        }
        do throws(PrescribedMotionError) { _ = try PrescribedMotionSegment(startTime: 0,endTime: Double.leastNonzeroMagnitude,start: zero,end: end);Issue.record("Unrepresentable inverse duration admitted") }
        catch { if case .invalidInput = error {} else { Issue.record("Wrong duration refusal") } }
    }
}
