import Testing
import MechanicsCore
import MechanicsLoads
@Suite struct PassiveLawsTests {
    @Test func nonlinearTranslationAndTorsionEnergyDerivative() throws {
        for kind in [ScalarCoordinateKind.translation, .rotation] {
            let law = try PolynomialSpringDamper(coordinateKind: kind, restCoordinate: 0.2,
                quadraticStiffness: 3, quarticStiffness: 2, linearDamping: 4, cubicDamping: 1,
                maximumDisplacement: 2, maximumRate: 3)
            let service: any ScalarLoadEvaluating = ScalarLoadEvaluator()
            var work = try LoadFixtures.work()
            let r = try service.evaluate(law, coordinate: 0.7, rate: -0.8, work: &work)
            let h = 1e-5
            let a = try service.evaluate(law, coordinate: 0.7 + h, rate: -0.8, work: &work)
            let b = try service.evaluate(law, coordinate: 0.7 - h, rate: -0.8, work: &work)
            #expect(abs(-(a.potentialEnergy! - b.potentialEnergy!) / (2 * h) - r.conservative) < 1e-8)
            #expect(abs((try a.total() - b.total()) / (2 * h) - r.coordinateDerivative) < 1e-8)
            #expect(r.dissipatedPower >= 0 && abs(r.dissipatedPower + r.dissipative * -0.8) < 1e-12)
            #expect(throws: LoadError.outsideDomain) { try service.evaluate(law, coordinate: 3, rate: 0, work: &work) }
        }
        #expect(throws: LoadError.invalidPassiveLaw) { try PolynomialSpringDamper(coordinateKind: .translation, restCoordinate: 0, quadraticStiffness: -1, linearDamping: 0, maximumDisplacement: 1, maximumRate: 1) }
    }
    @Test func coupledChartBushingEnergyAndDissipation() throws {
        let bushing = try PassiveChartBushing(frame: LoadFixtures.frame(), stiffnessFactor: [2,0,0,3,0,0, 0,1,0,0,0,0],
            dampingFactor: [1,0,0,1,0,0], maximumAbsoluteStrain: [Double](repeating: 2, count: 6),
            maximumAbsoluteRate: [Double](repeating: 2, count: 6))
        let q = [0.2, 0.4, 0, 0.3, 0, 0], v = [1.0,0,0,-0.5,0,0]
        let service: any ChartBushingEvaluating = ChartBushingEvaluator()
        var work = try LoadFixtures.work()
        let r = try service.evaluate(bushing, strain: q, rate: v, work: &work)
        #expect(abs(r.potentialEnergy - ((2 * 0.2 + 3 * 0.3) * (2 * 0.2 + 3 * 0.3) + 0.4 * 0.4) / 2) < 1e-12)
        #expect(r.dissipatedPower == 0.25)
        var dissipativePower = 0.0
        for i in 0..<6 {
            var plus = q, minus = q; plus[i] += 1e-5; minus[i] -= 1e-5
            let energyPlus = try service.evaluate(bushing, strain: plus, rate: v, work: &work).potentialEnergy
            let energyMinus = try service.evaluate(bushing, strain: minus, rate: v, work: &work).potentialEnergy
            #expect(abs(-(energyPlus - energyMinus) / 2e-5 - r.conservative[i]) < 1e-9)
            dissipativePower += r.dissipative[i] * v[i]
        }
        #expect(dissipativePower == -r.dissipatedPower)
        let tangent = try service.tangent(bushing, damping: false, work: &work)
        #expect(tangent[3] == -6 && tangent[18] == -6 && tangent[21] == -9)
        var small = try LoadFixtures.work(scalars: 11)
        #expect(throws: LoadError.capacityExceeded) { try service.evaluate(bushing, strain: q, rate: v, work: &small) }
    }
    @Test func affineGravityMassQuadratureAndPotential() throws {
        let gradient = try Matrix3(2,1,0, 1,3,0, 0,0,-1)
        let field = try AffineGravity(frame: LoadFixtures.frame(), accelerationAtOrigin: Vector3(0,-10,0), gradient: gradient, uniformTimeDerivative: .unitY)
        let service: any GravityEvaluating = GravityEvaluator()
        var work = try LoadFixtures.work()
        let point = try Vector3(1,2,3), sample = try GravitySample(point: point, mass: 2)
        let r = try service.point(field, body: LoadFixtures.body(), sample: sample, work: &work)
        #expect(try r.load.forces.total() == Vector3(8,-6,-6))
        #expect(r.explicitPotentialTimeDerivative == -4)
        let h = 1e-5
        for axis in [Vector3.unitX, .unitY, .unitZ] {
            let plus = try service.point(field, body: LoadFixtures.body(), sample: GravitySample(point: point.adding(axis.scaled(by: h)), mass: 2), work: &work)
            let minus = try service.point(field, body: LoadFixtures.body(), sample: GravitySample(point: point.subtracting(axis.scaled(by: h)), mass: 2), work: &work)
            #expect(abs(-(plus.load.potentialEnergy! - minus.load.potentialEnergy!) / (2*h) - (try r.load.forces.total().dot(axis))) < 1e-8)
        }
        let uniform = try AffineGravity(frame: LoadFixtures.frame(), accelerationAtOrigin: Vector3(0,-10,0))
        let equivalent = try service.distributed(uniform, body: LoadFixtures.body(), samples: [GravitySample(point: Vector3(1,0,0), mass: 2), GravitySample(point: Vector3(-1,0,0), mass: 1)], referencePoint: .zero, work: &work)
        #expect(equivalent.wrench.force == (try Vector3(0,-30,0)))
        #expect(equivalent.wrench.torque == (try Vector3(0,0,-10)))
        #expect(throws: LoadError.invalidPassiveLaw) { try AffineGravity(frame: LoadFixtures.frame(), accelerationAtOrigin: .zero, gradient: Matrix3(0,1,0,0,0,0,0,0,0)) }
    }
    @Test func fixedPressureAndMediumPowerDerivative() throws {
        var work = try LoadFixtures.work()
        let traction: any TractionEvaluating = TractionEvaluator()
        let samples = [try TractionSample(point: Vector3(2,0,0), area: 3, outwardNormal: .unitY, pressure: 4)]
        let e = try traction.equivalent(body: LoadFixtures.body(), frame: LoadFixtures.frame(), samples: samples, referencePoint: .zero, follower: false, work: &work)
        #expect(e.wrench.force == (try Vector3(0,-12,0)))
        #expect(e.wrench.torque == (try Vector3(0,0,-24)))
        #expect(e.potentialEnergy == nil)
        #expect(throws: LoadError.unsupportedDomain) { try traction.equivalent(body: LoadFixtures.body(), frame: LoadFixtures.frame(), samples: samples, referencePoint: .zero, follower: true, work: &work) }
        let medium = try LumpedMedium(density: 1000, velocity: .unitX, gravity: Vector3(0,-10,0))
        let law = try LumpedFluidLaw(linearDrag: 2, quadraticDrag: 3, displacedVolume: 0.01, maximumRelativeSpeed: 5)
        let service: any FluidLoadEvaluating = FluidLoadEvaluator(), velocity = try Vector3(3,0,0)
        let r = try service.evaluate(law, medium: medium, body: LoadFixtures.body(), frame: LoadFixtures.frame(), centerOfBuoyancyAndDrag: .unitY, velocity: velocity, work: &work)
        #expect(r.load.forces.dissipative == (try Vector3(-16,0,0)))
        #expect(r.load.forces.conservative == (try Vector3(0,100,0)))
        #expect(r.relativeDissipatedPower == 32 && r.prescribedMediumPower == -16)
        #expect(try r.load.forces.dissipative.dot(velocity) == -r.relativeDissipatedPower + r.prescribedMediumPower)
        #expect(r.forceVelocityDerivative.m00 == -14 && r.forceVelocityDerivative.m11 == -8)
        let a = try service.evaluate(law, medium: medium, body: LoadFixtures.body(), frame: LoadFixtures.frame(), centerOfBuoyancyAndDrag: .unitY, velocity: Vector3(3.00001,0,0), work: &work)
        let b = try service.evaluate(law, medium: medium, body: LoadFixtures.body(), frame: LoadFixtures.frame(), centerOfBuoyancyAndDrag: .unitY, velocity: Vector3(2.99999,0,0), work: &work)
        #expect(abs((a.load.forces.dissipative.x - b.load.forces.dissipative.x) / 2e-5 - r.forceVelocityDerivative.m00) < 1e-8)
        #expect(throws: LoadError.outsideDomain) { try service.evaluate(law, medium: medium, body: LoadFixtures.body(), frame: LoadFixtures.frame(), centerOfBuoyancyAndDrag: .zero, velocity: Vector3(10,0,0), work: &work) }
    }
}
