import Testing
import SwiftMechanics

@Suite struct SphereAddedInertiaTests {
    let service: any SphereAddedInertiaEvaluating = SphereAddedInertiaEvaluator()
    func law() throws -> SphereAddedInertiaLaw {
        try SphereAddedInertiaLaw(radius: 0.5, fluidDensity: 1000, maximumSpeed: 100, maximumAcceleration: 100)
    }
    @Test func sphereCoefficientAndStationaryFluid() throws {
        let p = try law()
        #expect(ThreeModelFixture.near(p.displacedMass, 1000 * Double.pi / 6))
        #expect(p.addedMass == p.displacedMass / 2)
        var work = try ThreeModelFixture.work()
        let r = try service.evaluate(law: p, bodyVelocity: Vector3(2,-1,3), bodyAcceleration: Vector3(1,2,-1),
                                     fluidVelocity: .zero, fluidAcceleration: .zero, work: &work)
        #expect(try ThreeModelFixture.vectorNear(r.totalForce, Vector3(-p.addedMass,-2*p.addedMass,p.addedMass)))
        #expect(r.pressureGradientForce == .zero && r.prescribedMediumPower == 0)
        #expect(ThreeModelFixture.near(r.relativeKineticEnergy, 7*p.addedMass))
        #expect(ThreeModelFixture.near(r.relativeKineticEnergyRate, -3*p.addedMass))
        #expect(ThreeModelFixture.near(r.powerResidual, 0))
        #expect(ThreeModelFixture.near(r.addedMassMatrix.m00, p.addedMass))
    }
    @Test func acceleratedMediumIncludesPressureAndPower() throws {
        let p = try law(); var work = try ThreeModelFixture.work()
        let vb = try Vector3(2,3,1), vf = try Vector3(-1,2,0)
        let ab = try Vector3(1,-1,2), af = try Vector3(3,2,-1)
        let r = try service.evaluate(law: p, bodyVelocity: vb, bodyAcceleration: ab, fluidVelocity: vf, fluidAcceleration: af, work: &work)
        #expect(try ThreeModelFixture.vectorNear(r.pressureGradientForce, af.scaled(by: p.displacedMass)))
        #expect(try ThreeModelFixture.vectorNear(r.totalForce, af.scaled(by: 1.5*p.displacedMass).subtracting(ab.scaled(by: p.addedMass))))
        #expect(try ThreeModelFixture.near(r.prescribedPressurePower, r.pressureGradientForce.dot(vb)))
        #expect(ThreeModelFixture.near(r.powerResidual, 0))
        let common = try service.evaluate(law: p, bodyVelocity: vf, bodyAcceleration: af, fluidVelocity: vf, fluidAcceleration: af, work: &work)
        #expect(common.addedInertiaForce == .zero && common.relativeKineticEnergy == 0)
        #expect(common.totalForce == common.pressureGradientForce)
    }
    @Test func forceDerivativesAndRotationCovariance() throws {
        let p = try law(); var work = try ThreeModelFixture.work()
        let vb = try Vector3(1,2,3), ab = try Vector3(2,-1,0), vf = try Vector3(-1,0,2), af = try Vector3(1,2,-2)
        let r = try service.evaluate(law: p, bodyVelocity: vb, bodyAcceleration: ab, fluidVelocity: vf, fluidAcceleration: af, work: &work)
        let d = try Vector3(0.3,-0.2,0.7), h = 1e-5
        let perturbed = try service.evaluate(law: p, bodyVelocity: vb, bodyAcceleration: ab.adding(d.scaled(by: h)), fluidVelocity: vf, fluidAcceleration: af, work: &work)
        let numerical = try perturbed.totalForce.subtracting(r.totalForce).scaled(by: 1/h)
        #expect(try ThreeModelFixture.vectorNear(numerical, r.bodyAccelerationDerivative.applying(to: d)))
        let fluidPerturbed = try service.evaluate(law: p, bodyVelocity: vb, bodyAcceleration: ab,
            fluidVelocity: vf, fluidAcceleration: af.adding(d.scaled(by: h)), work: &work)
        let fluidNumerical = try fluidPerturbed.totalForce.subtracting(r.totalForce).scaled(by: 1/h)
        #expect(try ThreeModelFixture.vectorNear(fluidNumerical, r.fluidAccelerationDerivative.applying(to: d)))
        #expect(try ThreeModelFixture.vectorNear(r.addedInertiaForce.adding(r.addedMassMatrix.applying(to: ab)),
                                                  r.addedMassMatrix.applying(to: af)))
        let rotation = try UnitQuaternion(axis: Vector3(1,2,3), angle: 0.4)
        let rotated = try service.evaluate(law: p, bodyVelocity: rotation.rotating(vb), bodyAcceleration: rotation.rotating(ab),
            fluidVelocity: rotation.rotating(vf), fluidAcceleration: rotation.rotating(af), work: &work)
        #expect(try ThreeModelFixture.vectorNear(rotated.totalForce, rotation.rotating(r.totalForce)))
        #expect(ThreeModelFixture.near(rotated.relativeKineticEnergy, r.relativeKineticEnergy))
        #expect(ThreeModelFixture.near(rotated.powerResidual, 0))
    }
    @Test func finiteDomainAndBudgetFailures() throws {
        let p = try law(); var work = try ThreeModelFixture.work()
        #expect(throws: LoadError.outsideDomain) {
            try service.evaluate(law: p, bodyVelocity: Vector3(101,0,0), bodyAcceleration: .zero, fluidVelocity: .zero, fluidAcceleration: .zero, work: &work)
        }
        var cancelled = try ThreeModelFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) {
            try service.evaluate(law: p, bodyVelocity: .zero, bodyAcceleration: .zero, fluidVelocity: .zero, fluidAcceleration: .zero, work: &cancelled)
        }
        var exhausted = try ThreeModelFixture.work(maximumWork: 79)
        #expect(throws: LoadError.workExhausted) {
            try service.evaluate(law: p, bodyVelocity: .zero, bodyAcceleration: .zero, fluidVelocity: .zero, fluidAcceleration: .zero, work: &exhausted)
        }
        #expect(throws: LoadError.nonFiniteResult) { try SphereAddedInertiaLaw(radius: 1e150, fluidDensity: 1, maximumSpeed: 1, maximumAcceleration: 1) }
    }
}
