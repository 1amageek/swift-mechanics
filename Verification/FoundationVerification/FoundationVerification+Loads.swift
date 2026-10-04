import SwiftMechanics

extension FoundationVerification {
    static func verifyLoads() throws {
        var work = LoadWork(budget: try LoadBudget(maximumWork: 1000, maximumScalars: 100))
        let scalar: any ScalarLoadEvaluating = ScalarLoadEvaluator()
        let spring = try PolynomialSpringDamper(coordinateKind: .translation, restCoordinate: 0,
            quadraticStiffness: 2, quarticStiffness: 4, linearDamping: 3,
            maximumDisplacement: 2, maximumRate: 5)
        let response = try scalar.evaluate(spring, coordinate: 0.5, rate: 2, work: &work)
        guard abs(response.conservative + 1.5) < 1e-12,
              abs(response.dissipative + 6) < 1e-12,
              response.potentialEnergy == 0.3125, response.dissipatedPower == 12 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let world = try EntityID(kind: .frame, key: "load-probe-world")
        let body = try EntityID(kind: .body, key: "load-probe-body")
        let gravity: any GravityEvaluating = GravityEvaluator()
        let field = try AffineGravity(frame: world, accelerationAtOrigin: Vector3(0,-10,0),
            gradient: Matrix3(2,0,0,0,0,0,0,0,0))
        let gravityResponse = try gravity.point(field, body: body,
            sample: GravitySample(point: Vector3(3,4,0), mass: 2), work: &work)
        guard gravityResponse.load.forces.conservative == (try Vector3(12,-20,0)),
              gravityResponse.load.potentialEnergy == 62 else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let router: any CableRouting = StraightCableRouter()
        let points = [try RoutePoint(frame: world, position: .zero, coordinateColumns: [.zero]),
            try RoutePoint(frame: world, position: Vector3(3,4,0), coordinateColumns: [.unitX],
                prescribedVelocity: .unitY)]
        let route = try router.evaluate(points: points, branch: .straightWaypoints, coordinateRate: [2],
            secondDerivativeDirection: [1], minimumSegmentLength: 1e-9, work: &work)
        let pull = try route.generalizedPull(tension: 10, work: &work)
        guard abs(route.length - 5) < 1e-12, abs(route.coordinateGradient[0] - 0.6) < 1e-12,
              abs(route.directionalSecondDerivative - 0.128) < 1e-12,
              abs(route.virtualLengthRate - 1.2) < 1e-12, abs(route.prescribedLengthRate - 0.8) < 1e-12,
              abs(pull[0] + 6) < 1e-12 else { throw FoundationVerificationError.analyticCheckFailed }
        let custom: any CustomLoadEvaluating = CustomLoadEvaluator()
        let customPolicy = try CustomLoadPolicy(minimumCoordinate: -2, maximumCoordinate: 2,
            maximumAbsoluteRate: 5, coordinateProbe: 1e-5, rateProbe: 1e-5,
            absoluteTolerance: 1e-8, relativeTolerance: 1e-8, requireConservativeEnergy: true)
        let customResponse = try custom.evaluate(RuntimeLoadLaw(), state: CustomLoadState(revision: 1, values: []),
            coordinate: 0.5, rate: 2, policy: customPolicy, work: &work)
        guard customResponse.conservative == -1, customResponse.dissipative == -6,
              customResponse.potentialEnergy == 0.25 else { throw FoundationVerificationError.analyticCheckFailed }
        var cancelled = LoadWork(budget: try LoadBudget(maximumWork: 1000, maximumScalars: 100, isCancelled: { true }))
        var rejected = false
        do throws(LoadError) {
            _ = try scalar.evaluate(spring, coordinate: 0, rate: 0, work: &cancelled)
        } catch {
            guard error == .cancelled else { throw FoundationVerificationError.analyticCheckFailed }
            rejected = true
        }
        guard rejected else { throw FoundationVerificationError.analyticCheckFailed }
    }
}
