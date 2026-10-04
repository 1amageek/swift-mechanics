import SwiftMechanics
import Testing
import Foundation

@Suite(.timeLimit(.minutes(1)))
struct PlanarPrescribedRootReactionPhysicalTests {
    private func wrench(_ w: PlanarReactionWrench, _ x: Double, _ y: Double, _ m: Double) {
        #expect(abs(w.forceX-x) < 1e-8);#expect(abs(w.forceY-y) < 1e-8);#expect(abs(w.momentZ-m) < 1e-8)
    }
    private func opposite(_ a: PlanarReactionWrench, _ b: PlanarReactionWrench) {
        wrench(b,-a.forceX,-a.forceY,-a.momentZ)
    }
    @Test func independentOffsetCOMNewtonEulerAndRootEffort() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),result=try f.recover(),t=f.state.time
            let theta=0.4+0.2*t+0.15*t*t,w=0.2+0.3*t
            let x=cos(theta)*0.4+sin(theta)*0.3,y=sin(theta)*0.4-cos(theta)*0.3
            let fx=2*(0.3-0.3*y-w*w*x),fy=2*(0.2+0.3*x-w*w*y),m=5*0.3+x*fy-y*fx
            wrench(result.support.supportOnRoot,fx,fy,m);opposite(result.support.supportOnRoot,result.support.rootOnSupport)
            #expect(result.joints.isEmpty && result.originalRank.rank == 3 && result.originalRank.reactionNullity == 0)
            for (i,value) in [fx,fy,m].enumerated() { #expect(abs(result.rootActuationEffort[i]-value) < 1e-8) }
            #expect(result.source.motion.system === f.constraint.system)
            #expect(result.support.timeSeconds.bitPattern == t.bitPattern && result.support.temporalMeaning == .instantaneousContinuousForce)
            #expect(result.maximumScaledOriginalGeneralizedResidual < 1e-8 && result.maximumScaledRootEffortResidual < 1e-8)
            // Independent root-origin power, rather than a producer energy diagnostic.
            let power=fx*(0.4+0.3*t)+fy*(-0.2+0.2*t)+m*w
            let comPower=fx*(0.4+0.3*t-w*y)+fy*(-0.2+0.2*t+w*x)+5*w*0.3
            #expect(abs(power-comPower) < 1e-12)
        }
    }
    @Test func translatingRootSliderOriginalCutsAndSupport() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(slider:true),r=try f.recover(),cut=try #require(r.joints.first)
            wrench(cut.parentOnChild,0,2,0);opposite(cut.parentOnChild,cut.childOnParent)
            wrench(r.support.supportOnRoot,0,3,4);opposite(r.support.supportOnRoot,r.support.rootOnSupport)
            #expect(abs(r.rootActuationEffort[1]-3) < 1e-8 && abs(r.rootActuationEffort[2]-4) < 1e-8)
            #expect(abs(f.motion.motion.values[3]) < 1e-10)
            let point=try Vector3(2,0.5*f.state.time*f.state.time,0)
            #expect(cut.referencePointWorld == point)
            #expect(cut.referencePoint == cut.referencePointWorld)
            #expect(r.support.referencePointWorld == f.constraint.system.input.snapshot.bodies[0].motion.pose.translation)
        }
    }
    @Test func distinctRootGravityAndNonunitNormalization() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let a=try PlanarPrescribedRootReactionFixtures(slider:true,gravity:true),b=try PlanarPrescribedRootReactionFixtures(slider:true,scale:3,gravity:true)
            let r=try a.recover(),s=try b.recover()
            wrench(r.joints[0].parentOnChild,0,22,0);wrench(r.support.supportOnRoot,0,33,44)
            wrench(s.support.supportOnRoot,r.support.supportOnRoot.forceX,r.support.supportOnRoot.forceY,r.support.supportOnRoot.momentZ)
            for i in 0..<3 { #expect(abs(b.motion.motion.rowMultipliers[i]-3*a.motion.motion.rowMultipliers[i]) < 1e-8) }
            #expect(r.loadWork.consumed == 6 && s.loadWork.consumed == 6)
        }
    }
    @Test func bodyFramedOffsetLoadAndRotationAtActualPoints() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let load=try BodyWrenchContribution(body:PlanarPrescribedRootReactionFixtures.id(.body,"support-root"),
                frame:PlanarPrescribedRootReactionFixtures.id(.frame,"support-root-frame"),referencePoint:.unitX,
                wrench:SpatialWrench(torque:.zero,force:Vector3(0,3,0)),channel:.applied)
            let f=try PlanarPrescribedRootReactionFixtures(bodyLoads:[load]),base=try PlanarPrescribedRootReactionFixtures()
            let world=try f.recover(),unloaded=try base.recover(),framed=try f.recover(frame:f.constraint.base.frame)
            let t=f.state.time,theta=0.4+0.2*t+0.15*t*t
            let fx=unloaded.support.supportOnRoot.forceX+3*sin(theta),fy=unloaded.support.supportOnRoot.forceY-3*cos(theta)
            wrench(world.support.supportOnRoot,fx,fy,unloaded.support.supportOnRoot.momentZ-3)
            wrench(framed.support.supportOnRoot,cos(theta)*fx+sin(theta)*fy,-sin(theta)*fx+cos(theta)*fy,world.support.supportOnRoot.momentZ)
            #expect(abs(framed.support.referencePoint.x) < 1e-12 && abs(framed.support.referencePoint.y) < 1e-12 && framed.support.referencePoint.z == 0)
            #expect(framed.support.referencePointWorld == world.support.referencePointWorld)
            opposite(framed.support.supportOnRoot,framed.support.rootOnSupport)
        }
    }
    @Test func rawOffPlaneReferenceCoupleCancellationSurvivesReduction() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let load=try BodyWrenchContribution(body:PlanarPrescribedRootReactionFixtures.id(.body,"support-root"),
                frame:PlanarPrescribedRootReactionFixtures.id(.frame,"support-world"),referencePoint:Vector3(0,0,1),
                wrench:SpatialWrench(torque:Vector3(0,-10,0),force:Vector3(10,0,0)),channel:.applied)
            let f=try PlanarPrescribedRootReactionFixtures(bodyLoads:[load]),base=try PlanarPrescribedRootReactionFixtures()
            let r=try f.recover(),b=try base.recover(),y=2-0.2*f.state.time+0.1*f.state.time*f.state.time
            wrench(r.support.supportOnRoot,b.support.supportOnRoot.forceX-10,b.support.supportOnRoot.forceY,b.support.supportOnRoot.momentZ-10*y)
        }
    }
}
