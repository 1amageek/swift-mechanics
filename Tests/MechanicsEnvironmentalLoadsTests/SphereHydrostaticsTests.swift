import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct SphereHydrostaticsTests {
    @Test func independentHemisphereDryAndFullValues() throws {
        let service: any SphereHydrostaticEvaluating = SphereHydrostaticEvaluator()
        let law = try SphereHydrostaticLaw(radius: 2, density: 3, gravitationalAcceleration: 10)
        var work = try EnvironmentalLoadFixture.work()
        let half = try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),
            center:.zero,planePoint:.zero,upwardNormal:.unitZ,work:&work)
        #expect(work.consumed == 200 && work.peakScalars == 64)
        #expect(EnvironmentalLoadFixture.close(half.displacedVolume,16*Double.pi/3))
        #expect(EnvironmentalLoadFixture.close(half.centerOfBuoyancy!.z,-0.75))
        #expect(EnvironmentalLoadFixture.close(half.load.forces.conservative.z,160*Double.pi))
        #expect(EnvironmentalLoadFixture.close(half.waterplaneArea,4*Double.pi))
        #expect(EnvironmentalLoadFixture.close(half.load.potentialEnergy!,120*Double.pi))
        let dry = try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),
            center:Vector3(0,0,2),planePoint:.zero,upwardNormal:.unitZ,work:&work)
        #expect(dry.displacedVolume == 0 && dry.centerOfBuoyancy == nil && dry.load.forces.conservative == .zero)
        let full = try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),
            center:Vector3(0,0,-3),planePoint:.zero,upwardNormal:.unitZ,work:&work)
        #expect(EnvironmentalLoadFixture.close(full.displacedVolume,32*Double.pi/3))
        #expect(full.centerOfBuoyancy == (try Vector3(0,0,-3)))
        #expect(EnvironmentalLoadFixture.close(full.load.potentialEnergy!,960*Double.pi))
    }
    @Test func originalPotentialAndForceDerivativesAndRotation() throws {
        let service: any SphereHydrostaticEvaluating = SphereHydrostaticEvaluator()
        let law = try SphereHydrostaticLaw(radius:1,density:2,gravitationalAcceleration:3)
        var work = try EnvironmentalLoadFixture.work()
        func evaluate(_ center:Vector3,_ n:Vector3 = .unitZ) throws -> SphereHydrostaticResponse {
            try service.evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),center:center,
                planePoint:.zero,upwardNormal:n,work:&work)
        }
        let h=1e-5, c=try Vector3(0,0,0.2), r=try evaluate(c)
        let plus=try evaluate(Vector3(0,0,0.2+h)), minus=try evaluate(Vector3(0,0,0.2-h))
        #expect(EnvironmentalLoadFixture.close(-(plus.load.potentialEnergy!-minus.load.potentialEnergy!)/(2*h),r.load.forces.conservative.z,tolerance:1e-8))
        #expect(EnvironmentalLoadFixture.close((plus.load.forces.conservative.z-minus.load.forces.conservative.z)/(2*h),r.forcePositionDerivative.m22,tolerance:1e-8))
        let q=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.9), rotated=try evaluate(q.rotating(c),q.rotating(.unitZ))
        #expect(try EnvironmentalLoadFixture.close(rotated.load.forces.conservative,q.rotating(r.load.forces.conservative)))
        #expect(try EnvironmentalLoadFixture.close(rotated.centerOfBuoyancy!,q.rotating(r.centerOfBuoyancy!)))
    }
    @Test func invalidAndResourceFailures() throws {
        #expect(throws:LoadError.invalidInput) { try SphereHydrostaticLaw(radius:-1,density:1,gravitationalAcceleration:1) }
        let law=try SphereHydrostaticLaw(radius:1,density:1,gravitationalAcceleration:1)
        for (units,slots,cancelled,error) in [(199,64,false,LoadError.workExhausted),(200,63,false,.capacityExceeded),(200,64,true,.cancelled)] {
            var work=try EnvironmentalLoadFixture.work(units,scalars:slots,cancelled:cancelled)
            #expect(throws:error) { try SphereHydrostaticEvaluator().evaluate(law,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),center:.zero,planePoint:.zero,upwardNormal:.unitZ,work:&work) }
        }
    }
}
