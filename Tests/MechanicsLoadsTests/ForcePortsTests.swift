import SwiftMechanics
import Testing
@Suite struct ForcePortsTests {
    @Test func pointJacobianAndPrescribedPower() throws {
        let snapshot = try LoadFixtures.snapshot(prescribed: true), body = try LoadFixtures.body()
        let service: any KinematicJacobianComputing = KinematicJacobianCalculator()
        let jacobian = try service.point(body: body, bodyLocalPoint: .unitX, snapshot: snapshot)
        let load = try FramedPointLoad(body: body, frame: LoadFixtures.frame(), point: jacobian.pointWorld,
            forces: ForceParts(conservative: Vector3(0, 4, 0), dissipative: Vector3(0, -1, 0), active: Vector3(0, 2, 0)))
        var work = try LoadFixtures.work()
        let mapper: any LoadMapping = LoadMapper(), result = try mapper.point(load, jacobian: jacobian, rate: [2], work: &work)
        #expect(result.values == [5])
        #expect(result.power.virtual == 10 && result.power.prescribedDrift == 15 && result.power.actual == 25)
        #expect(result.power.conservativeActual == 20 && result.power.dissipativeActual == -5 && result.power.activeActual == 10)
        for j in [try service.geometric(body: body, snapshot: snapshot), try service.spatial(body: body, snapshot: snapshot)] {
            #expect(try mapper.wrench(load.wrench(about: j.referencePointWorld), load: load, jacobian: j, rate: [2], work: &work) == [5])
        }
        #expect(snapshot.coordinateRate == [2])
    }
    @Test func offcenterImpulseFrameTransformAndFailures() throws {
        let body = try LoadFixtures.body(), frame = try LoadFixtures.frame()
        let load = try FramedPointLoad(body: body, frame: frame, point: Vector3(2, 0, 0), forces: ForceParts(active: Vector3(0, 3, 0)))
        #expect(try load.wrench(about: .zero).torque == Vector3(0, 0, 6))
        let impulse = try FramedImpulse(body: body, frame: frame, point: Vector3(2, 0, 0), impulse: Vector3(0, 3, 0), angularImpulse: Vector3(0, 0, 1))
        #expect(try impulse.equivalent(about: .zero).torque == Vector3(0, 0, 7))
        let transform = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: .pi / 2), translation: try Vector3(1, 2, 0))
        let moved = try load.transformed(to: EntityID(kind: .frame, key: "other"), by: transform)
        #expect(try moved.point.subtracting(Vector3(1, 4, 0)).magnitude() < 1e-12)
        #expect(try moved.forces.total().subtracting(Vector3(-3, 0, 0)).magnitude() < 1e-12)
        let snapshot = try LoadFixtures.snapshot(), service = KinematicJacobianCalculator()
        let jacobian = try service.point(body: body, bodyLocalPoint: load.point, snapshot: snapshot)
        var work = try LoadFixtures.work()
        #expect(throws: LoadError.frameMismatch) { try LoadMapper().point(moved, jacobian: jacobian, rate: [1], work: &work) }
        let geometric = try service.geometric(body: body, snapshot: snapshot)
        #expect(try LoadMapper().impulse(impulse, jacobian: geometric, work: &work) == [7])
    }
    @Test func exactResourceBoundaries() throws {
        let snapshot = try LoadFixtures.snapshot(), body = try LoadFixtures.body()
        let jacobian = try KinematicJacobianCalculator().point(body: body, bodyLocalPoint: .unitX, snapshot: snapshot)
        let load = try FramedPointLoad(body: body, frame: LoadFixtures.frame(), point: jacobian.pointWorld, forces: ForceParts(active: .unitY))
        var capacity = try LoadFixtures.work(scalars: 0), exhausted = try LoadFixtures.work(1), exact = try LoadFixtures.work(2, scalars: 1)
        #expect(throws: LoadError.capacityExceeded) { try LoadMapper().point(load, jacobian: jacobian, rate: [1], work: &capacity) }
        #expect(throws: LoadError.workExhausted) { try LoadMapper().point(load, jacobian: jacobian, rate: [1], work: &exhausted) }
        #expect(exhausted.consumed == 1)
        #expect(try LoadMapper().point(load, jacobian: jacobian, rate: [1], work: &exact).values == [1])
        #expect(exact.consumed == 2 && exact.peakScalars == 1)
        var cancelled = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 100, isCancelled: { true }))
        #expect(throws: LoadError.cancelled) { try LoadMapper().point(load, jacobian: jacobian, rate: [1], work: &cancelled) }
        #expect(throws: LoadError.capacityExceeded) { try LoadWork.product(Int.max, 2) }
        #expect(throws: LoadError.capacityExceeded) { try LoadWork.sum(Int.max, 1) }
    }
}
