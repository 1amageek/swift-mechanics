import SwiftMechanics
import Foundation
import Testing
@Suite struct MechanicalDerivativeTests {
    @Test func twoLinkMassBiasGravityAndNonzeroAcceleration() throws {
        let input=try DerivativeFixtures.twoLink(), d=DerivativeFixtures.zero(input,q:[0,1])
        let out=try DerivativeFixtures.tangent(input,d), hprime=4.8*cos(-0.6)
        #expect(DerivativeFixtures.close(out.massMatrix[0],-9.6*sin(-0.6)))
        #expect(DerivativeFixtures.close(out.massMatrix[1],-4.8*sin(-0.6)))
        #expect(DerivativeFixtures.close(out.massMatrix[2],out.massMatrix[1]))
        #expect(abs(out.massMatrix[3]) < 1e-8)
        #expect(DerivativeFixtures.close(out.inertialBias[0],0.48*hprime))
        #expect(DerivativeFixtures.close(out.inertialBias[1],0.64*hprime))
        #expect(DerivativeFixtures.close(out.totalForce[0],24*sin(-0.3)))
        #expect(DerivativeFixtures.close(out.totalForce[1],24*sin(-0.3)))
        let dk=0.5*(0.8*0.8*out.massMatrix[0]+2*0.8*(-0.4)*out.massMatrix[1])
        #expect(DerivativeFixtures.close(out.kineticEnergy,dk))
        // The supplied acceleration is [99,-17]; it must cancel out of the zero-generalized-acceleration bias.
        let epsilon=1e-6
        let plus=try DerivativeFixtures.shifted(input,q:[0.3,-0.6+epsilon]), minus=try DerivativeFixtures.shifted(input,q:[0.3,-0.6-epsilon])
        let p=try DerivativeFixtures.tangent(plus,DerivativeFixtures.zero(plus)), m=try DerivativeFixtures.tangent(minus,DerivativeFixtures.zero(minus))
        for i in 0..<4 { #expect(DerivativeFixtures.close(out.massMatrix[i],(p.system.massMatrix[i]-m.system.massMatrix[i])/(2*epsilon),1e-6)) }
        for i in 0..<2 { #expect(DerivativeFixtures.close(out.inertialBias[i],(p.system.inertialBias[i]-m.system.inertialBias[i])/(2*epsilon),1e-6)) }
        // The child origin is on its hinge; changing the second angle rotates its COM but does not move the origin or its world-axis columns.
        #expect(out.tree.geometricColumns.allSatisfy { abs($0.linear.x)+abs($0.linear.y)+abs($0.angular.z) < 1e-8 })
        #expect(DerivativeFixtures.close(out.tree.bodies[2].rotationMatrix.m00,-sin(-0.3)))
    }
    @Test func asymmetricFreeEulerBodyCoordinatesAndOrientation() throws {
        let input=try DerivativeFixtures.freeBody()
        let out=try DerivativeFixtures.forward(input,DerivativeFixtures.zero(input,v:[0,0,0,0,1,0]))
        #expect(DerivativeFixtures.close(out.mechanics.inertialBias[3],3))
        #expect(abs(out.mechanics.inertialBias[4]) < 1e-8)
        #expect(DerivativeFixtures.close(out.mechanics.inertialBias[5],1))
        #expect(DerivativeFixtures.close(out.acceleration[3],-1.5))
        #expect(DerivativeFixtures.close(out.acceleration[5],-0.25))
        #expect(out.originalResidual <= out.originalThreshold)
        let orientation=try DerivativeFixtures.tangent(input,DerivativeFixtures.zero(input,q:[0,0,0,0.2,-0.4,0.3]))
        #expect(orientation.massMatrix.allSatisfy { abs($0) < 1e-8 })
        #expect(orientation.inertialBias.allSatisfy { abs($0) < 1e-8 })
        #expect(orientation.tree.geometricColumns.contains { abs($0.angular.x)+abs($0.angular.y)+abs($0.angular.z) > 0.1 })
    }
    @Test func quaternionChartColumnsAndCoordinateRateIndependentOracle() throws {
        let input=try DerivativeFixtures.freeBody(), eta=try Vector3(0.2,-0.4,0.3)
        let d=DerivativeFixtures.zero(input,q:[0,0,0,eta.x,eta.y,eta.z]), tangent=try DerivativeFixtures.tangent(input,d)
        let q=try UnitQuaternion(w:input.state.q[3],x:input.state.q[4],y:input.state.q[5],z:input.state.q[6]), epsilon=1e-6
        let plusQ=try q.multiplied(by:UnitQuaternion(rotationVector:eta.scaled(by:epsilon)))
        let minusQ=try q.multiplied(by:UnitQuaternion(rotationVector:eta.scaled(by:-epsilon)))
        let plus=try DerivativeFixtures.shifted(input,q:[0.2,0.4,-0.1,plusQ.w,plusQ.x,plusQ.y,plusQ.z])
        let minus=try DerivativeFixtures.shifted(input,q:[0.2,0.4,-0.1,minusQ.w,minusQ.x,minusQ.y,minusQ.z])
        let p=try TreeKinematicsEvaluator().evaluate(plus.tree,state:plus.state,policy:DerivativeFixtures.jointPolicy())
        let m=try TreeKinematicsEvaluator().evaluate(minus.tree,state:minus.state,policy:DerivativeFixtures.jointPolicy())
        let pc=try p.geometricColumns(body:input.inertias[0].body), mc=try m.geometricColumns(body:input.inertias[0].body)
        for (i, pair) in zip(pc,mc).enumerated() {
            #expect(DerivativeFixtures.close(tangent.tree.geometricColumns[i].angular.x,(pair.0.angular.x-pair.1.angular.x)/(2*epsilon),1e-6))
            #expect(DerivativeFixtures.close(tangent.tree.geometricColumns[i].angular.y,(pair.0.angular.y-pair.1.angular.y)/(2*epsilon),1e-6))
            #expect(DerivativeFixtures.close(tangent.tree.geometricColumns[i].angular.z,(pair.0.angular.z-pair.1.angular.z)/(2*epsilon),1e-6))
        }
        for i in 0..<7 { #expect(DerivativeFixtures.close(tangent.tree.coordinateRate[i],(p.coordinateRate[i]-m.coordinateRate[i])/(2*epsilon),1e-6)) }
    }
    @Test func offsetCOMParameterAndScaledImplicitAcceleration() throws {
        let input=try DerivativeFixtures.pendulum()
        var dirs=input.inertias.map { BodyInertiaDirection(body:$0.body,frame:$0.frame) }
        dirs[1]=BodyInertiaDirection(body:input.inertias[1].body,frame:input.inertias[1].frame,centerOfMass:.unitX)
        let d=DerivativeFixtures.zero(input,inertias:dirs), out=try DerivativeFixtures.forward(input,d,scaled:true)
        #expect(DerivativeFixtures.close(out.mechanics.massMatrix[0],4))
        #expect(DerivativeFixtures.close(out.mechanics.totalForce[0],-20*cos(0.4)))
        let a=(2-20*cos(0.4))/6
        #expect(DerivativeFixtures.close(out.primal.acceleration[0],a))
        #expect(DerivativeFixtures.close(out.acceleration[0],(-20*cos(0.4)-4*a)/6))
        let ordinary=try DerivativeFixtures.forward(input,d)
        #expect(DerivativeFixtures.close(out.acceleration[0],ordinary.acceleration[0]))
        #expect(out.originalResidual <= out.originalThreshold)
    }
    @Test func bodyFrameWrenchAndGravityTimeProducts() throws {
        let load=try BodyWrenchContribution(body:DerivativeFixtures.id(.body,"pendulum"),frame:DerivativeFixtures.id(.frame,"pendulum-frame"),
            referencePoint:Vector3(1,0,0),wrench:SpatialWrench(torque:.zero,force:Vector3(0,3,0)),channel:.applied)
        let input=try DerivativeFixtures.pendulum(wrenches:[load],gravityTime:Vector3(0,3,0))
        let out=try DerivativeFixtures.tangent(input,DerivativeFixtures.zero(input,q:[1]))
        #expect(DerivativeFixtures.close(out.totalForce[0],20*sin(0.4)))
        // Body-fixed force/pin moment has constant scalar conjugate torque; its orientation derivative is zero.
        #expect(DerivativeFixtures.close(out.actualLoadPower,14*sin(0.4)))
        let time=try DerivativeFixtures.tangent(input,DerivativeFixtures.zero(input,time:2))
        #expect(DerivativeFixtures.close(time.totalForce[0],12*cos(0.4)))
        #expect(DerivativeFixtures.close(time.gravityPotential,-12*sin(0.4)))
    }
    @Test func prescribedDriftAccelerationDirection() throws {
        let input=try DerivativeFixtures.pendulum(prescribed:true)
        let d=DerivativeFixtures.zero(input,prescribed:[FrameMotionDirection(linearVelocity:.unitY,linearAcceleration:.unitX)])
        let out=try DerivativeFixtures.tangent(input,d)
        #expect(DerivativeFixtures.close(out.tree.bodies[1].prescribedDrift.linear.y,1))
        #expect(DerivativeFixtures.close(out.tree.bodies[1].accelerationBias.linear.x,1))
        #expect(DerivativeFixtures.close(out.inertialBias[0],-2*sin(0.4)))
        #expect(DerivativeFixtures.close(out.prescribedLoadPower,-20))
        #expect(abs(out.virtualLoadPower) < 1e-8)
    }
    @Test func fullVelocityJacobianAndIndependentDirectionalDifference() throws {
        let input=try DerivativeFixtures.twoLink()
        var s=MechanicalDerivativeWorkspace(), w=try DerivativeFixtures.work(), l=try DerivativeFixtures.loadWork(), calls=try DerivativeSupplierWork(maximumCalls:1000)
        let service:any MechanicalDifferentiating=ExactMechanicalDifferentiator()
        let jac=try service.forwardJacobian(input,variable:.velocity,jointPolicy:DerivativeFixtures.jointPolicy(),admission:DerivativeFixtures.admission(),
            solvePolicy:DerivativeFixtures.solvePolicy(2),policy:DerivativeFixtures.policy(),workspace:&s,loadWork:&l,supplierWork:&calls,work:&w)
        let epsilon=1e-6
        for column in 0..<2 {
            var vp=input.state.v, vm=vp; vp[column]+=epsilon; vm[column]-=epsilon
            let plus=try DerivativeFixtures.shifted(input,v:vp), minus=try DerivativeFixtures.shifted(input,v:vm)
            let pa=try DerivativeFixtures.forward(plus,DerivativeFixtures.zero(plus)), ma=try DerivativeFixtures.forward(minus,DerivativeFixtures.zero(minus))
            for row in 0..<2 { #expect(DerivativeFixtures.close(jac.values[row*2+column],(pa.primal.acceleration[row]-ma.primal.acceleration[row])/(2*epsilon),1e-6)) }
        }
        #expect(jac.values.count == 4)
        // Two basis iterations plus the real nested factorization/solve iterations must remain in the cumulative ledger.
        #expect(w.iterations > 2)
    }
    @Test func screwPitchAndPrismaticProducts() throws {
        let root=try DerivativeFixtures.properties(1), child=try DerivativeFixtures.properties(2)
        let j=try DerivativeFixtures.hinge("screw","root","child",manifold:JointManifold(.screw(axis:.unitZ,pitchMetersPerRadian:0.4)))
        let input=try DerivativeFixtures.input([DerivativeFixtures.body("root",root),DerivativeFixtures.body("child",child)],[j],
            [DerivativeFixtures.inertia("root",root),DerivativeFixtures.inertia("child",child)],q:[0.7],v:[0.8],acceleration:[3])
        let zero=DerivativeFixtures.zero(input)
        let td=TreeDirection(revision:7,configuration:[0],velocity:[0],acceleration:[0],screwPitch:[1])
        let d=MechanicalDirection(tree:td,inertias:zero.inertias,drive:[0])
        let out=try DerivativeFixtures.tangent(input,d)
        #expect(DerivativeFixtures.close(out.tree.bodies[1].translation.z,0.7))
        #expect(DerivativeFixtures.close(out.tree.geometricColumns[1].linear.z,1))
        #expect(DerivativeFixtures.close(out.massMatrix[0],1.6))
        #expect(out.inertialBias.allSatisfy { abs($0) < 1e-8 })
    }
    @Test func universalJointAnchorTransportDirectionalOracle() throws {
        let root=try DerivativeFixtures.properties(1), child=try DerivativeFixtures.properties(2,Vector3(0.3,0.2,0.4),Matrix3(2,0,0,0,3,0,0,0,4))
        let joint=try JointRecord(id:DerivativeFixtures.id(.joint,"universal"),parentBody:DerivativeFixtures.id(.body,"root"),childBody:DerivativeFixtures.id(.body,"child"),
            parentAnchor:JointAnchor(frame:DerivativeFixtures.id(.frame,"u-parent"),placement:.fixed(RigidTransform(rotation:UnitQuaternion(axis:.unitY,angle:0.5),translation:Vector3(1,-0.2,0.7)))),
            childAnchor:JointAnchor(frame:DerivativeFixtures.id(.frame,"u-child"),placement:.fixed(RigidTransform(rotation:UnitQuaternion(axis:.unitX,angle:0.2),translation:Vector3(0.1,0.3,-0.2)))),
            manifold:JointManifold(.universal(firstAxis:.unitX,secondAxis:.unitY)))
        let x=try DerivativeFixtures.input([DerivativeFixtures.body("root",root),DerivativeFixtures.body("child",child)],[joint],
            [DerivativeFixtures.inertia("root",root),DerivativeFixtures.inertia("child",child)],q:[0.4,-0.3],v:[1.2,-0.7],acceleration:[17,-22])
        let direction=[0.2,0.5], d=DerivativeFixtures.zero(x,q:direction), out=try DerivativeFixtures.tangent(x,d), epsilon=1e-6
        let plus=try DerivativeFixtures.shifted(x,q:[0.4+epsilon*direction[0],-0.3+epsilon*direction[1]])
        let minus=try DerivativeFixtures.shifted(x,q:[0.4-epsilon*direction[0],-0.3-epsilon*direction[1]])
        let p=try DerivativeFixtures.tangent(plus,DerivativeFixtures.zero(plus)), m=try DerivativeFixtures.tangent(minus,DerivativeFixtures.zero(minus))
        for i in 0..<4 { #expect(DerivativeFixtures.close(out.massMatrix[i],(p.system.massMatrix[i]-m.system.massMatrix[i])/(2*epsilon),1e-6)) }
        for i in 0..<2 { #expect(DerivativeFixtures.close(out.inertialBias[i],(p.system.inertialBias[i]-m.system.inertialBias[i])/(2*epsilon),1e-6)) }
    }
    @Test func sphericalChildOfMovingHingeDirectionalOracle() throws {
        let root=try DerivativeFixtures.properties(1), middle=try DerivativeFixtures.properties(1), child=try DerivativeFixtures.properties(2,Vector3(0.3,0.2,0.4),Matrix3(2,0,0,0,3,0,0,0,4))
        let j1=try DerivativeFixtures.hinge("hinge","root","middle")
        let j2=try DerivativeFixtures.hinge("sphere","middle","child",.fixed(RigidTransform(rotation:.identity,translation:Vector3(2,0.3,0.5))),manifold:JointManifold(.spherical))
        let rotation=try UnitQuaternion(axis:.unitY,angle:0.3), eta=try Vector3(0.1,-0.3,0.2)
        let x=try DerivativeFixtures.input([DerivativeFixtures.body("root",root),DerivativeFixtures.body("middle",middle),DerivativeFixtures.body("child",child)],[j1,j2],
            [DerivativeFixtures.inertia("root",root),DerivativeFixtures.inertia("middle",middle),DerivativeFixtures.inertia("child",child)],
            q:[0.4,rotation.w,rotation.x,rotation.y,rotation.z],v:[0.6,0.4,-0.2,0.7],acceleration:[15,22,-11,9])
        let out=try DerivativeFixtures.tangent(x,DerivativeFixtures.zero(x,q:[0.2,eta.x,eta.y,eta.z])), epsilon=1e-6
        let qp=try rotation.multiplied(by:UnitQuaternion(rotationVector:eta.scaled(by:epsilon))), qm=try rotation.multiplied(by:UnitQuaternion(rotationVector:eta.scaled(by:-epsilon)))
        let plus=try DerivativeFixtures.shifted(x,q:[0.4+0.2*epsilon,qp.w,qp.x,qp.y,qp.z]), minus=try DerivativeFixtures.shifted(x,q:[0.4-0.2*epsilon,qm.w,qm.x,qm.y,qm.z])
        let p=try DerivativeFixtures.tangent(plus,DerivativeFixtures.zero(plus)), m=try DerivativeFixtures.tangent(minus,DerivativeFixtures.zero(minus))
        for i in 0..<16 { #expect(DerivativeFixtures.close(out.massMatrix[i],(p.system.massMatrix[i]-m.system.massMatrix[i])/(2*epsilon),1e-6)) }
        for i in 0..<4 { #expect(DerivativeFixtures.close(out.inertialBias[i],(p.system.inertialBias[i]-m.system.inertialBias[i])/(2*epsilon),1e-6)) }
    }

}
