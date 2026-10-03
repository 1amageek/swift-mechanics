import Testing
import MechanicsCore
import MechanicsLoads
@Suite struct CableRoutingTests {
    private func points(_ q: Double) throws -> [RoutePoint] {
        let frame = try LoadFixtures.frame()
        return [try RoutePoint(frame: frame, position: .zero, coordinateColumns: [.zero]),
                try RoutePoint(frame: frame, position: Vector3(1,q,0), coordinateColumns: [.unitY], prescribedVelocity: .unitX),
                try RoutePoint(frame: frame, position: Vector3(3,0,0), coordinateColumns: [.zero])]
    }
    @Test func independentLengthGradientHessianAndVirtualWork() throws {
        let service: any CableRouting = StraightCableRouter()
        var work = try LoadFixtures.work()
        func evaluate(_ q: Double) throws -> CableRouteResponse {
            try service.evaluate(points: points(q), branch: .straightWaypoints, coordinateRate: [2], secondDerivativeDirection: [1], minimumSegmentLength: 1e-8, work: &work)
        }
        let q = 0.7, h = 1e-4, r = try evaluate(q), a = try evaluate(q+h), b = try evaluate(q-h)
        #expect(abs(r.length - ((1+q*q).squareRoot()+(4+q*q).squareRoot())) < 1e-12)
        #expect(abs((a.length-b.length)/(2*h)-r.coordinateGradient[0]) < 1e-8)
        #expect(abs((a.coordinateGradient[0]-b.coordinateGradient[0])/(2*h)-r.directionalSecondDerivative) < 1e-8)
        let generalized = try r.generalizedPull(tension: 5, work: &work)
        #expect(abs(generalized[0] * 2 + 5 * r.virtualLengthRate) < 1e-12)
        #expect(abs(-5 * r.waypointGradient[1].y - generalized[0]) < 1e-12)
        #expect(abs(r.prescribedLengthRate - (1/(1+q*q).squareRoot()-2/(4+q*q).squareRoot())) < 1e-12)
        #expect(try r.actualLengthRate() == r.virtualLengthRate + r.prescribedLengthRate)
        #expect(work.peakScalars == 10)
    }
    @Test func branchDegeneracyShapeAndBudgets() throws {
        let service = StraightCableRouter(), frame = try LoadFixtures.frame()
        var work = try LoadFixtures.work()
        for branch in [CableBranch.pulley, .wrapping] {
            #expect(throws: LoadError.unsupportedDomain) { try service.evaluate(points: points(0.5), branch: branch, coordinateRate: [1], secondDerivativeDirection: [1], minimumSegmentLength: 1e-8, work: &work) }
        }
        let coincident = [try RoutePoint(frame: frame, position: .zero, coordinateColumns: []), try RoutePoint(frame: frame, position: .zero, coordinateColumns: [])]
        #expect(throws: LoadError.degenerateRoute) { try service.evaluate(points: coincident, branch: .straightWaypoints, coordinateRate: [], secondDerivativeDirection: [], minimumSegmentLength: 1e-8, work: &work) }
        var capacity = try LoadFixtures.work(scalars: 9), budget = try LoadFixtures.work(0)
        #expect(throws: LoadError.capacityExceeded) { try service.evaluate(points: points(0.5), branch: .straightWaypoints, coordinateRate: [1], secondDerivativeDirection: [1], minimumSegmentLength: 1e-8, work: &capacity) }
        #expect(throws: LoadError.workExhausted) { try service.evaluate(points: points(0.5), branch: .straightWaypoints, coordinateRate: [1], secondDerivativeDirection: [1], minimumSegmentLength: 1e-8, work: &budget) }
        #expect(throws: LoadError.invalidPassiveLaw) { try service.evaluate(points: points(0.5), branch: .straightWaypoints, coordinateRate: [1], secondDerivativeDirection: [1], minimumSegmentLength: 1e-8, work: &work).generalizedPull(tension: -1, work: &work) }
    }
}
