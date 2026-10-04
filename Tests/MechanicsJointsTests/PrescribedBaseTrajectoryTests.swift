import Foundation
import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PrescribedBaseTrajectoryTests {
    @Test func harmonicSpatialChartPreservesBodyRatesAndTrueQuaternionDerivative() throws {
        let program = try PrescribedTrajectoryFixtures.base(.harmonic(PrescribedTrajectoryFixtures.harmonic()))
        let sampler: any PrescribedBaseTrajectorySampling = AnalyticPrescribedBaseTrajectorySampler()
        var work = try PrescribedTrajectoryFixtures.work()
        let t = 0.37, x = PrescribedTrajectoryFixtures.harmonicOracle(t)
        let sample = try OriginalPrescribedBaseTrajectoryAcceptance.sealedBaseMotion(program,time: t,policy: program.policy,sampler: sampler,work: &work)
        let c = cos(x.angle/2),s = sin(x.angle/2),a = cos(0.2),b = sin(0.2)
        let q = x.p+[c*a,c*b,s*b,s*a]
        let v = x.v+[0,sin(0.4)*x.omega,cos(0.4)*x.omega]
        let acc = x.a+[0,sin(0.4)*x.alpha,cos(0.4)*x.alpha]
        let rate = x.v+[-0.5*x.omega*s*a,-0.5*x.omega*s*b,0.5*x.omega*c*b,0.5*x.omega*c*a]
        #expect(sample.layout == .spatialFloating && sample.q.count == 7 && sample.v.count == 6)
        for i in q.indices { #expect(abs(sample.q[i]-q[i]) < 3e-14);#expect(abs(sample.coordinateRate[i]-rate[i]) < 3e-14) }
        for i in v.indices { #expect(abs(sample.v[i]-v[i]) < 3e-14);#expect(abs(sample.a[i]-acc[i]) < 3e-14) }
        let h = 1e-5
        let before = try sampler.sampleBase(program,time: t-h,policy: program.policy,work: &work)
        let after = try sampler.sampleBase(program,time: t+h,policy: program.policy,work: &work)
        for i in q.indices { #expect(abs((after.q[i]-before.q[i])/(2*h)-rate[i]) < 4e-10) }
        for i in v.indices { #expect(abs((after.v[i]-before.v[i])/(2*h)-acc[i]) < 4e-10) }
        let initial = try sampler.sampleBase(program,time: 0,policy: program.policy,work: &work)
        #expect(initial.q[3].bitPattern == program.trajectory.initialPose.rotation.w.bitPattern)
        #expect(initial.q[4].bitPattern == program.trajectory.initialPose.rotation.x.bitPattern)
    }

    @Test func piecewisePlanarAngleNeverResetsAtKnotsOrPrincipalBranch() throws {
        let law = try PrescribedTrajectoryFixtures.piecewise(planar: true)
        let program = try PrescribedTrajectoryFixtures.base(.piecewise(law),planar: true)
        var work = try PrescribedTrajectoryFixtures.work()
        for t in [0.0,0.8,1,1.6,2] {
            let x = PrescribedTrajectoryFixtures.polynomial(t)
            let sample = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time: t,policy: program.policy,work: &work)
            #expect(abs(sample.q[2]-(0.4+2*x.p)) < 2e-13)
            #expect(abs(sample.v[2]-2*x.v) < 2e-13 && abs(sample.a[2]-2*x.a) < 2e-12)
            #expect(sample.coordinateRate == sample.v)
            if t == 2 { #expect(sample.q[2] > 6*Double.pi) }
        }
    }

    @Test func planarChartRejectsOriginalOutOfPlaneAmplitudeAndEndpointJets() throws {
        let harmonic = try PrescribedTrajectoryFixtures.harmonic()
        let piecewise = try PrescribedTrajectoryFixtures.piecewise()
        let policy = try PrescribedTrajectoryFixtures.policy()
        var work = try PrescribedTrajectoryFixtures.work()
        for trajectory in [PrescribedTrajectory.harmonic(harmonic),.piecewise(piecewise)] {
            do throws(PrescribedMotionError) { _ = try PrescribedBaseTrajectoryProgram(trajectory: trajectory,layout: .planarFloating,policy: policy,work: &work);Issue.record("Out of plane source admitted") }
            catch { if case .nonPlanarMotion = error {} else { Issue.record("Wrong plane refusal") } }
        }
        let planar = try PrescribedTrajectoryFixtures.piecewise(planar: true), end = planar.segments[1].end
        let bad = try PrescribedMotionJet(displacement: end.displacement,angle: end.angle,linearVelocity: Vector3(end.linearVelocity.x,end.linearVelocity.y,1),
            angularRate: end.angularRate,linearAcceleration: end.linearAcceleration,angularAcceleration: end.angularAcceleration)
        let segment = try PrescribedMotionSegment(startTime: 1,endTime: 2,start: planar.segments[1].start,end: bad)
        let changed = try PiecewisePrescribedMotion(frame: planar.frame,parentFrame: planar.parentFrame,initialPose: planar.initialPose,rotationAxis: .unitZ,
            segments: [planar.segments[0],segment],policy: policy,work: &work)
        do throws(PrescribedMotionError) { _ = try PrescribedBaseTrajectoryProgram(trajectory: .piecewise(changed),layout: .planarFloating,policy: policy,work: &work);Issue.record("Nonplanar derivative jet admitted") }
        catch { if case .nonPlanarMotion = error {} else { Issue.record("Wrong derivative-plane refusal") } }
        do throws(PrescribedMotionError) { _ = try PrescribedBaseTrajectoryProgram(trajectory: .piecewise(planar),layout: .fixed,policy: policy,work: &work);Issue.record("Fixed chart admitted") }
        catch { if case .unsupportedChart = error {} else { Issue.record("Wrong chart refusal") } }
    }

    @Test func quadraticTaggedAdapterPreservesLegacyFieldsAndSampleBits() throws {
        for planar in [false,true] {
            let old = try PrescribedBaseMotionFixtures.program(planar: planar)
            let law: AnalyticPrescribedMotion = old.law
            var preparation = try PrescribedTrajectoryFixtures.work()
            let oldAnchor = try PrescribedMotionProgram(motions: [law],policy: old.policy,work: &preparation)
            let oldLaws: [AnalyticPrescribedMotion] = oldAnchor.motions
            #expect(oldLaws[0].translationAcceleration == law.translationAcceleration)
            let new = try PrescribedTrajectoryFixtures.base(.quadratic(law),planar: planar)
            var work = try PrescribedTrajectoryFixtures.work()
            for time in [0.0,0.7,6] {
                let a = try AnalyticPrescribedBaseMotionSampler().sampleBase(old,time: time,policy: old.policy,work: &work)
                let b = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(new,time: time,policy: new.policy,work: &work)
                for (x,y) in zip(a.q+a.v+a.a+a.coordinateRate,b.q+b.v+b.a+b.coordinateRate) { #expect(x.bitPattern == y.bitPattern) }
                #expect(a.motion == b.motion && a.frame == b.frame && a.worldFrame == b.worldFrame)
                #expect(a.metadata == old.metadata && b.metadata == new.metadata && a.metadata != b.metadata)
            }
            #expect(old.metadata.hasPrefix("analytic-base-v1") && oldAnchor.metadata.hasPrefix("analytic-anchor-v1"))
            #expect(new.metadata.hasPrefix("trajectory-base-v1"))
            #expect(law.angularAcceleration == 0.3 && law.translationAcceleration.x == 0.3)
        }
    }
}
