import SwiftMechanics
import Testing
import Foundation

@Suite struct PlanarTreeBehaviorTests {
    private func compare(_ actual: Vector3, _ plus: Vector3, _ minus: Vector3, _ h: Double) {
        #expect(PlanarTreeFixtures.close(actual.x,(plus.x-minus.x)/(2*h)))
        #expect(PlanarTreeFixtures.close(actual.y,(plus.y-minus.y)/(2*h)))
        #expect(PlanarTreeFixtures.close(actual.z,(plus.z-minus.z)/(2*h)))
    }
    private func compare(_ actual: SpatialMotion, _ plus: SpatialMotion, _ minus: SpatialMotion, _ h: Double) {
        compare(actual.angular,plus.angular,minus.angular,h); compare(actual.linear,plus.linear,minus.linear,h)
    }
    private func independentDifference(_ x: PlanarTreeFixtures) throws {
        let h=1e-6, out=try x.tangent(), plus=try x.shifted(h), minus=try x.shifted(-h)
        #expect(out.snapshot.tree.revision == x.tree.revision && out.snapshot.time == x.state.time)
        #expect(out.bodies.count == x.tree.bodies.count && out.coordinateRate.count == x.state.q.count)
        #expect(out.geometricColumns.count == x.tree.bodies.count*x.state.v.count)
        for i in out.bodies.indices {
            let a=out.bodies[i], p=plus.bodies[i], m=minus.bodies[i]
            #expect(a.body == p.body && a.frame == p.bodyFrame)
            compare(a.translation,p.motion.pose.translation,m.motion.pose.translation,h)
            compare(a.velocity,p.motion.velocity,m.motion.velocity,h)
            compare(a.acceleration,p.motion.acceleration,m.motion.acceleration,h)
            compare(a.prescribedDrift,p.prescribedDriftVelocity,m.prescribedDriftVelocity,h)
            compare(a.accelerationBias,p.accelerationBias,m.accelerationBias,h)
            let pr=try p.motion.pose.rotation.matrix(), mr=try m.motion.pose.rotation.matrix()
            for r in 0..<3 { for c in 0..<3 {
                #expect(PlanarTreeFixtures.close(try a.rotationMatrix.element(row:r,column:c),
                    (try pr.element(row:r,column:c)-mr.element(row:r,column:c))/(2*h)))
            } }
            let pc=try plus.geometricColumns(body:a.body), mc=try minus.geometricColumns(body:a.body)
            for (k,pcol) in pc.enumerated() { compare(out.geometricColumns[i*x.state.v.count+k],pcol,mc[mc.startIndex+k],h) }
        }
        for i in out.coordinateRate.indices {
            #expect(PlanarTreeFixtures.close(out.coordinateRate[i],(plus.coordinateRate[i]-minus.coordinateRate[i])/(2*h)))
        }
    }
    @Test func fixedBranchedRevolutePrismaticAndPlanarFactors() throws { try independentDifference(PlanarTreeFixtures.branched(false)) }
    @Test func planarFloatingRootAndBranchedFactors() throws { try independentDifference(PlanarTreeFixtures.branched(true)) }
    @Test func bothPrescribedAnchorDirectionsAndNonzeroAccelerationBias() throws { try independentDifference(PlanarTreeFixtures.prescribed()) }
    @Test func fixedFactorAndCustomOrderedPlanarAxes() throws {
        let joints=try [PlanarTreeFixtures.joint("fixed","root","first",.fixed,parentPose:PlanarTreeFixtures.pose(0.6,-0.3,0.2)),
            PlanarTreeFixtures.joint("custom","first","tip",.custom(orderedAxes:[
                JointAxis(kind:.revolute,direction:.unitZ),JointAxis(kind:.prismatic,direction:.unitX),
                JointAxis(kind:.revolute,direction:Vector3(0,0,-1))]),childPose:PlanarTreeFixtures.pose(-0.8,0.1,-0.4))]
        try independentDifference(PlanarTreeFixtures.make([PlanarTreeFixtures.body("root"),PlanarTreeFixtures.body("first"),PlanarTreeFixtures.body("tip")],joints,
            q:[0.2,0.6,-0.3],v:[0.7,-0.4,0.2],a:[11,-6,4],dq:[-0.3,0.5,0.2],dv:[0.2,-0.6,0.4],da:[1.2,-0.8,0.9]))
    }
    @Test func exactHingeOffsetPhysicalOracle() throws {
        let x=try PlanarTreeFixtures.hinge(), out=try x.tangent(), tip=out.bodies[1]
        let q=x.state.q[0], v=x.state.v[0], a=x.state.acceleration[0], dq=x.direction.configuration[0], dv=x.direction.velocity[0], da=x.direction.acceleration[0]
        let u=try Vector3(cos(q),sin(q),0), normal=try Vector3(-sin(q),cos(q),0)
        let dp=try normal.scaled(by:2*dq), dvel=try normal.scaled(by:2*dv).subtracting(u.scaled(by:2*v*dq))
        let dbias=try u.scaled(by:-4*v*dv).adding(normal.scaled(by:-2*v*v*dq))
        let dacc=try dbias.adding(normal.scaled(by:2*da)).subtracting(u.scaled(by:2*a*dq))
        #expect(PlanarTreeFixtures.close(tip.translation.x,dp.x) && PlanarTreeFixtures.close(tip.translation.y,dp.y))
        #expect(PlanarTreeFixtures.close(tip.velocity.linear.x,dvel.x) && PlanarTreeFixtures.close(tip.velocity.linear.y,dvel.y))
        #expect(PlanarTreeFixtures.close(tip.accelerationBias.linear.x,dbias.x) && PlanarTreeFixtures.close(tip.accelerationBias.linear.y,dbias.y))
        #expect(PlanarTreeFixtures.close(tip.acceleration.linear.x,dacc.x) && PlanarTreeFixtures.close(tip.acceleration.linear.y,dacc.y))
        #expect(tip.acceleration.angular.z == da && tip.prescribedDrift == SpatialMotion(angular:.zero,linear:.zero))
        let dc=out.geometricColumns[1].linear
        #expect(PlanarTreeFixtures.close(dc.x,-2*cos(q)*dq) && PlanarTreeFixtures.close(dc.y,-2*sin(q)*dq))
        #expect(out.coordinateRate == x.direction.velocity)
    }
    @Test func siblingColumnsStayZeroAndScratchReusePreservesPublishedOutput() throws {
        let x=try PlanarTreeFixtures.branched(true), service:any TreeDifferentiating=ExactPlanarTreeDifferentiator()
        var scratch=TreeTangentWorkspace(), work=try PlanarTreeFixtures.work(), calls=try DerivativeSupplierWork(maximumCalls:100)
        let first=try service.direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
        let saved=first.bodies[3].translation, n=x.state.v.count
        for k in 4..<7 { #expect(first.geometricColumns[3*n+k] == SpatialMotion(angular:.zero,linear:.zero)) }
        #expect(first.geometricColumns[2*n+3] == SpatialMotion(angular:.zero,linear:.zero))
        work=try PlanarTreeFixtures.work()
        let second=try service.direction(x.tree,state:x.state,direction:x.direction,jointPolicy:PlanarTreeFixtures.jointPolicy(),policy:PlanarTreeFixtures.policy(),workspace:&scratch,supplierWork:&calls,work:&work)
        #expect(first.bodies[3].translation == saved && second.bodies[3].translation == saved)
        #expect(calls.calls == 2*(1+x.tree.bodies.count) && work.operations > 0)
    }
}
