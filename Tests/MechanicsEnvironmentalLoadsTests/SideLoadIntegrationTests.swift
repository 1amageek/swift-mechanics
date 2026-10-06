import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct SideLoadIntegrationTests {
    @Test func fiveLoadsComposeIntoTheSameFramedWrench() throws {
        var work=try EnvironmentalLoadFixture.work()
        let body=try EnvironmentalLoadFixture.body(), frame=try EnvironmentalLoadFixture.frame()
        let sphere:any SphereHydrostaticEvaluating=SphereHydrostaticEvaluator()
        let drag:any HydrodynamicDragEvaluating=HydrodynamicDragEvaluator()
        let aero:any AerodynamicPolarEvaluating=AerodynamicPolarEvaluator()
        let pressure:any TrianglePressureEvaluating=TrianglePressureEvaluator()
        let gravity:any HarmonicGravityEvaluating=HarmonicGravityEvaluator()
        let s=try sphere.evaluate(SphereHydrostaticLaw(radius:1,density:2,gravitationalAcceleration:3),
            body:body,frame:frame,center:.unitX,planePoint:.zero,upwardNormal:.unitZ,work:&work)
        let d=try drag.evaluate(HydrodynamicDragLaw(axialCoefficient:2,transverseCoefficient:3,maximumRelativeSpeed:10),
            body:body,frame:frame,point:.unitX,longitudinalAxis:.unitX,velocity:.unitX,mediumVelocity:.zero,work:&work)
        let polar=try AerodynamicPolarLaw(samples:[AerodynamicPolarSample(angle:-1,liftCoefficient:1,dragCoefficient:1),
            AerodynamicPolarSample(angle:1,liftCoefficient:1,dragCoefficient:1)],area:2,minimumPlanarSpeed:0.5,
            maximumPlanarSpeed:10,maximumSpanwiseFraction:0,maximumBasisDot:0,work:&work)
        let a=try aero.evaluate(polar,density:2,body:body,frame:frame,point:.unitX,chordAxis:.unitX,
            spanAxis:Vector3(0,-1,0),velocity:.unitX,mediumVelocity:.zero,work:&work)
        let p=try pressure.evaluate(pressure:6,body:body,frame:frame,vertices:[.zero,.unitX,.unitY],
            velocities:[.zero,.zero,.zero],referencePoint:.zero,minimumTwiceArea:0,work:&work)
        let field=try HarmonicGravityLaw(frame:frame,constantAcceleration:Vector3(0,0,-3),cosineAcceleration:.zero,
            sineAcceleration:.zero,constantGradient:.zero,cosineGradient:.zero,sineGradient:.zero,angularFrequency:1,timeOrigin:0,phase:0)
        let g=try gravity.evaluate(field,body:body,sample:GravitySample(point:.unitX,mass:2),velocity:.zero,time:0,work:&work)
        let loads=[s.load,d.load,a.load,g.load]+p.nodalLoads
        var force=Vector3.zero, torque=Vector3.zero
        for load in loads {
            #expect(load.body == body && load.frame == frame)
            let wrench=try load.wrench(about:.zero)
            force=try force.adding(wrench.force);torque=try torque.adding(wrench.torque)
        }
        #expect(try EnvironmentalLoadFixture.close(force,Vector3(-4,0,4*Double.pi-7)))
        #expect(try EnvironmentalLoadFixture.close(torque,Vector3(-1,5-4*Double.pi,0)))
        let transform=RigidTransform(rotation:try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7),translation:try Vector3(2,-1,4))
        let destination=try EntityID(kind:.frame,key:"destination")
        var newForce=Vector3.zero,newTorque=Vector3.zero
        for load in loads {
            let wrench=try load.transformed(to:destination,by:transform).wrench(about:.zero)
            newForce=try newForce.adding(wrench.force);newTorque=try newTorque.adding(wrench.torque)
        }
        let expected=try transform.transforming(wrench:SpatialWrench(torque:torque,force:force))
        #expect(EnvironmentalLoadFixture.close(newForce,expected.force))
        #expect(EnvironmentalLoadFixture.close(newTorque,expected.torque))
    }
    @Test func everyEvaluatorHonorsCapacityCancellationAndWork() throws {
        // Fixed laws keep all five independent operations in the same exhausted ledger.
        let body=try EnvironmentalLoadFixture.body(), frame=try EnvironmentalLoadFixture.frame()
        var lawWork=try EnvironmentalLoadFixture.work()
        let polar=try AerodynamicPolarLaw(samples:[AerodynamicPolarSample(angle:-1,liftCoefficient:0,dragCoefficient:1),
            AerodynamicPolarSample(angle:1,liftCoefficient:0,dragCoefficient:1)],area:1,minimumPlanarSpeed:0.5,
            maximumPlanarSpeed:10,maximumSpanwiseFraction:0,maximumBasisDot:0,work:&lawWork)
        let field=try HarmonicGravityLaw(frame:frame,constantAcceleration:.zero,cosineAcceleration:.zero,sineAcceleration:.zero,
            constantGradient:.zero,cosineGradient:.zero,sineGradient:.zero,angularFrequency:1,timeOrigin:0,phase:0)
        for (units,slots,cancelled,error) in [(0,1000,false,LoadError.workExhausted),(10000,0,false,.capacityExceeded),(10000,1000,true,.cancelled)] {
            var work=try EnvironmentalLoadFixture.work(units,scalars:slots,cancelled:cancelled)
            #expect(throws:error) { try SphereHydrostaticEvaluator().evaluate(SphereHydrostaticLaw(radius:1,density:1,gravitationalAcceleration:1),body:body,frame:frame,center:.zero,planePoint:.zero,upwardNormal:.unitZ,work:&work) }
            #expect(throws:error) { try HydrodynamicDragEvaluator().evaluate(HydrodynamicDragLaw(axialCoefficient:1,transverseCoefficient:1,maximumRelativeSpeed:10),body:body,frame:frame,point:.zero,longitudinalAxis:.unitX,velocity:.unitX,mediumVelocity:.zero,work:&work) }
            #expect(throws:error) { try AerodynamicPolarEvaluator().evaluate(polar,density:1,body:body,frame:frame,point:.zero,chordAxis:.unitX,spanAxis:Vector3(0,-1,0),velocity:.unitX,mediumVelocity:.zero,work:&work) }
            #expect(throws:error) { try TrianglePressureEvaluator().evaluate(pressure:1,body:body,frame:frame,vertices:[.zero,.unitX,.unitY],velocities:[.zero,.zero,.zero],referencePoint:.zero,minimumTwiceArea:0,work:&work) }
            #expect(throws:error) { try HarmonicGravityEvaluator().evaluate(field,body:body,sample:GravitySample(point:.zero,mass:1),velocity:.zero,time:0,work:&work) }
        }
    }
}
