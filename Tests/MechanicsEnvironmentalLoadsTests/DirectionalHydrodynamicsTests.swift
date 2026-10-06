import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct DirectionalHydrodynamicsTests {
    @Test func independentAxialTransverseAndMediumWork() throws {
        let service:any HydrodynamicDragEvaluating=HydrodynamicDragEvaluator()
        let law=try HydrodynamicDragLaw(axialCoefficient:2,transverseCoefficient:3,maximumRelativeSpeed:20)
        var work=try EnvironmentalLoadFixture.work()
        let r=try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),point:.unitY,
            longitudinalAxis:.unitX,velocity:Vector3(3,3,0),mediumVelocity:.unitX,work:&work)
        #expect(r.load.forces.dissipative == (try Vector3(-8,-27,0)))
        #expect(r.relativeDissipatedPower == 97 && r.prescribedMediumPower == -8)
        #expect(try r.load.forces.dissipative.dot(Vector3(3,3,0)) == -r.relativeDissipatedPower+r.prescribedMediumPower)
        #expect(r.forceVelocityDerivative.m00 == -8 && r.forceVelocityDerivative.m11 == -18 && r.forceVelocityDerivative.m22 == -9)
    }
    @Test func allDerivativeColumnsAndFrameCovariance() throws {
        let service:any HydrodynamicDragEvaluating=HydrodynamicDragEvaluator()
        let law=try HydrodynamicDragLaw(axialCoefficient:2,transverseCoefficient:3,maximumRelativeSpeed:20)
        var work=try EnvironmentalLoadFixture.work()
        let v=try Vector3(2,3,4), axis=try Vector3(1,2,0)
        func evaluate(_ v:Vector3,_ a:Vector3) throws -> HydrodynamicDragResponse {
            try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),point:.zero,
                longitudinalAxis:a,velocity:v,mediumVelocity:.zero,work:&work)
        }
        let r=try evaluate(v,axis), h=1e-5
        for e in [Vector3.unitX,.unitY,.unitZ] {
            let plus=try evaluate(v.adding(e.scaled(by:h)),axis), minus=try evaluate(v.subtracting(e.scaled(by:h)),axis)
            let difference=try plus.load.forces.dissipative.subtracting(minus.load.forces.dissipative).scaled(by:1/(2*h))
            #expect(try EnvironmentalLoadFixture.close(difference,r.forceVelocityDerivative.applying(to:e),tolerance:1e-8))
        }
        let q=try UnitQuaternion(axis:.unitZ,angle:0.7), rotated=try evaluate(q.rotating(v),q.rotating(axis))
        #expect(try EnvironmentalLoadFixture.close(rotated.load.forces.dissipative,q.rotating(r.load.forces.dissipative)))
        let zero=try evaluate(.zero,axis)
        #expect(zero.load.forces.dissipative == .zero && zero.forceVelocityDerivative == .zero)
    }
    @Test func invalidAndOutsideEnvelope() throws {
        #expect(throws:LoadError.invalidInput) { try HydrodynamicDragLaw(axialCoefficient:-1,transverseCoefficient:1,maximumRelativeSpeed:2) }
        var work=try EnvironmentalLoadFixture.work()
        #expect(throws:LoadError.outsideDomain) { try HydrodynamicDragEvaluator().evaluate(HydrodynamicDragLaw(axialCoefficient:1,transverseCoefficient:1,maximumRelativeSpeed:1),body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),point:.zero,longitudinalAxis:.unitX,velocity:Vector3(2,0,0),mediumVelocity:.zero,work:&work) }
    }
}
