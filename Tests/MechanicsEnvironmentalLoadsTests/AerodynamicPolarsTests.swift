import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct AerodynamicPolarsTests {
    @Test func independentInterpolatedLiftDragAndWork() throws {
        var work=try EnvironmentalLoadFixture.work()
        let law=try AerodynamicPolarLaw(samples:[AerodynamicPolarSample(angle:-1,liftCoefficient:0,dragCoefficient:0.2),
            AerodynamicPolarSample(angle:1,liftCoefficient:2,dragCoefficient:0.4)],area:2,minimumPlanarSpeed:1,
            maximumPlanarSpeed:20,maximumSpanwiseFraction:0,maximumBasisDot:0,work:&work)
        let service:any AerodynamicPolarEvaluating=AerodynamicPolarEvaluator()
        let r=try service.evaluate(law,density:2,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),point:.unitX,
            chordAxis:.unitX,spanAxis:Vector3(0,-1,0),velocity:Vector3(11,0,0),mediumVelocity:.unitX,work:&work)
        #expect(r.angle == 0 && r.liftCoefficient == 1)
        #expect(EnvironmentalLoadFixture.close(r.dragCoefficient,0.3))
        #expect(r.dynamicPressure == 100)
        #expect(try EnvironmentalLoadFixture.close(r.load.forces.dissipative,Vector3(-60,0,200)))
        #expect(EnvironmentalLoadFixture.close(r.relativeDissipatedPower,600))
        #expect(EnvironmentalLoadFixture.close(r.prescribedMediumPower,-60))
        #expect(try EnvironmentalLoadFixture.close(r.load.forces.dissipative.dot(Vector3(11,0,0)),-660))
    }
    @Test func nonzeroAngleAndRotatedSectionRemainWorkConsistent() throws {
        var work=try EnvironmentalLoadFixture.work()
        let law=try AerodynamicPolarLaw(samples:[AerodynamicPolarSample(angle:-Double.pi/2,liftCoefficient:-2,dragCoefficient:0.5),
            AerodynamicPolarSample(angle:Double.pi/2,liftCoefficient:2,dragCoefficient:0.5)],area:1,minimumPlanarSpeed:1,
            maximumPlanarSpeed:10,maximumSpanwiseFraction:1e-12,maximumBasisDot:1e-12,work:&work)
        let service:any AerodynamicPolarEvaluating=AerodynamicPolarEvaluator()
        let v=try Vector3(2,0,2), span=try Vector3(0,-1,0)
        let original=try service.evaluate(law,density:2,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),
            point:.zero,chordAxis:.unitX,spanAxis:span,velocity:v,mediumVelocity:.zero,work:&work)
        #expect(EnvironmentalLoadFixture.close(original.angle,Double.pi/4))
        #expect(EnvironmentalLoadFixture.close(original.liftCoefficient,1))
        #expect(try EnvironmentalLoadFixture.close(original.load.forces.dissipative,Vector3(-12/Double(2).squareRoot(),0,4/Double(2).squareRoot())))
        #expect(try EnvironmentalLoadFixture.close(original.load.forces.dissipative.dot(v),-original.relativeDissipatedPower))
        let q=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.8)
        let rotated=try service.evaluate(law,density:2,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),
            point:.zero,chordAxis:q.rotating(.unitX),spanAxis:q.rotating(span),velocity:q.rotating(v),mediumVelocity:.zero,work:&work)
        #expect(EnvironmentalLoadFixture.close(rotated.angle,original.angle))
        #expect(try EnvironmentalLoadFixture.close(rotated.load.forces.dissipative,q.rotating(original.load.forces.dissipative)))
    }
    @Test func noExtrapolationCrossflowAndInvalidTable() throws {
        var work=try EnvironmentalLoadFixture.work()
        let sample=try AerodynamicPolarSample(angle:0,liftCoefficient:0,dragCoefficient:1)
        #expect(throws:LoadError.invalidInput) { try AerodynamicPolarLaw(samples:[sample,sample],area:1,minimumPlanarSpeed:1,maximumPlanarSpeed:10,maximumSpanwiseFraction:0,maximumBasisDot:0,work:&work) }
        let law=try AerodynamicPolarLaw(samples:[AerodynamicPolarSample(angle:-0.5,liftCoefficient:0,dragCoefficient:1),AerodynamicPolarSample(angle:0.5,liftCoefficient:0,dragCoefficient:1)],area:1,minimumPlanarSpeed:1,maximumPlanarSpeed:10,maximumSpanwiseFraction:0,maximumBasisDot:0,work:&work)
        for velocity in [Vector3.zero,try Vector3(0,0,2),try Vector3(2,1,0)] {
            #expect(throws:LoadError.outsideDomain) { try AerodynamicPolarEvaluator().evaluate(law,density:1,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),point:.zero,chordAxis:.unitX,spanAxis:Vector3(0,-1,0),velocity:velocity,mediumVelocity:.zero,work:&work) }
        }
    }
}
