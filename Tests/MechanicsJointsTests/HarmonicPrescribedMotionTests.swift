import Foundation
import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct HarmonicPrescribedMotionTests {
    @Test func nonidentityHarmonicPoseAndBothDerivativesMatchOriginalTrigonometry() throws {
        let law = try PrescribedTrajectoryFixtures.harmonic()
        let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(law)])
        let sampler: any PrescribedTrajectorySampling = AnalyticPrescribedTrajectorySampler()
        var work = try PrescribedTrajectoryFixtures.work()
        for t in [-1.0,0,0.37,Double.pi,Double.pi+0.37,8] {
            let sample = try sampler.sample(program, time: t, policy: program.policy, work: &work)
            let result = sample.anchors[0].motion, oracle = PrescribedTrajectoryFixtures.harmonicOracle(t)
            let p = result.pose.translation, v = result.velocity.linear, a = result.acceleration.linear
            for (actual,expected) in zip([p.x,p.y,p.z,v.x,v.y,v.z,a.x,a.y,a.z], oracle.p+oracle.v+oracle.a) { #expect(abs(actual-expected) < 3e-14) }
            let q = result.pose.rotation
            let expected = [cos(oracle.angle/2)*cos(0.2),cos(oracle.angle/2)*sin(0.2),sin(oracle.angle/2)*sin(0.2),sin(oracle.angle/2)*cos(0.2)]
            for (actual,expected) in zip([q.w,q.x,q.y,q.z],expected) { #expect(abs(actual-expected) < 2e-14) }
            #expect(result.velocity.angular.x == 0 && result.velocity.angular.y == 0)
            #expect(abs(result.velocity.angular.z-oracle.omega) < 2e-14)
            #expect(abs(result.acceleration.angular.z-oracle.alpha) < 2e-14)
            if t == 0 { #expect(result.pose == law.initialPose && result.velocity.angular.z != 0) }
        }
        let before = try sampler.sample(program, time: 0.37-1e-5, policy: program.policy, work: &work).anchors[0].motion
        let after = try sampler.sample(program, time: 0.37+1e-5, policy: program.policy, work: &work).anchors[0].motion
        let oracle = PrescribedTrajectoryFixtures.harmonicOracle(0.37)
        #expect(abs((after.pose.translation.x-before.pose.translation.x)/2e-5-oracle.v[0]) < 2e-10)
        #expect(abs((after.velocity.linear.x-before.velocity.linear.x)/2e-5-oracle.a[0]) < 2e-10)
    }

    @Test func invalidHarmonicLawAndTimeFailWithoutClamping() throws {
        let m = try PrescribedTrajectoryFixtures.harmonic()
        let body = try EntityID(kind: .body, key: "root")
        for frequency in [0.0,-1,Double.nan,Double.greatestFiniteMagnitude] {
            do throws(PrescribedMotionError) {
                _ = try HarmonicPrescribedMotion(frame: m.frame,parentFrame: m.parentFrame,referenceTime: 0,initialPose: m.initialPose,
                    translationSine: m.translationSine,translationCosine: m.translationCosine,rotationAxis: m.rotationAxis,
                    angularSine: m.angularSine,angularCosine: m.angularCosine,frequency: frequency,phase: m.phase,
                    minimumTime: -1,maximumTime: 8,maximumIdentifierBytes: 100)
                Issue.record("Invalid frequency admitted")
            } catch { if case .invalidInput = error {} else { Issue.record("Wrong frequency refusal") } }
        }
        do throws(PrescribedMotionError) {
            _ = try HarmonicPrescribedMotion(frame: body,parentFrame: m.parentFrame,referenceTime: 0,initialPose: m.initialPose,
                translationSine: m.translationSine,translationCosine: m.translationCosine,rotationAxis: .unitZ,
                angularSine: 0.4,angularCosine: -0.2,frequency: 2,phase: 0.3,minimumTime: -1,maximumTime: 8,maximumIdentifierBytes: 100)
            Issue.record("Body identifier admitted as frame")
        } catch { if case .invalidFrame = error {} else { Issue.record("Wrong frame refusal") } }
        do throws(PrescribedMotionError) {
            _ = try HarmonicPrescribedMotion(frame: m.frame,parentFrame: m.parentFrame,referenceTime: 0,initialPose: m.initialPose,
                translationSine: m.translationSine,translationCosine: m.translationCosine,rotationAxis: .zero,
                angularSine: 0.4,angularCosine: -0.2,frequency: 2,phase: 0.3,minimumTime: -1,maximumTime: 8,maximumIdentifierBytes: 100)
            Issue.record("Zero axis admitted")
        } catch { if case .invalidAxis = error {} else { Issue.record("Wrong axis refusal") } }
        let program = try PrescribedTrajectoryFixtures.anchor([.harmonic(m)])
        var work = try PrescribedTrajectoryFixtures.work()
        for time in [Double.nan,8.01] {
            do throws(PrescribedMotionError) { _ = try AnalyticPrescribedTrajectorySampler().sample(program,time: time,policy: program.policy,work: &work); Issue.record("Invalid time sampled") }
            catch { switch error { case .invalidInput: #expect(time.isNaN);case .outsideDomain: #expect(time == 8.01);default: Issue.record("Wrong time refusal") } }
        }
    }
}
