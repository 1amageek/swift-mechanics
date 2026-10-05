import SwiftMechanics

public enum RollingRelationsQualificationCases {
    private typealias F = RollingRelationsQualificationFixtures
    public static func require(_ condition: Bool,_ message: String) throws(RollingRelationsQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    private static func near(_ actual: Double,_ expected: Double,_ label: String,tolerance: Double = 1e-10) throws(RollingRelationsQualificationError) {
        try require(actual.isFinite && abs(actual-expected) <= tolerance+tolerance*abs(expected),label)
    }
    private static func vector(_ actual: Vector3,_ expected: Vector3,_ label: String) throws(RollingRelationsQualificationError) {
        try near(actual.x,expected.x,label+" x"); try near(actual.y,expected.y,label+" y"); try near(actual.z,expected.z,label+" z")
    }
    private static func expect(_ predicate: (RollingError) -> Bool,_ body: () throws(RollingRelationsQualificationError) -> Void) throws(RollingRelationsQualificationError) {
        do throws(RollingRelationsQualificationError) { try body() }
        catch {
            guard case .rolling(let original) = error, predicate(original) else { throw error }
            return
        }
        throw .assertion("Original typed refusal missing")
    }
    private static func rows(_ result: RollingEvaluation,fixture: F,normal: [String:Double],forward: [String:Double],lateral: [String:Double],
                             residual: [Double],acceleration: [Double],bias: [Double],drift: [Double] = [0,0,0]) throws(RollingRelationsQualificationError) {
        try require(result.rows.count == 3,"Original three rows missing")
        let authored = [normal,forward,lateral]
        let directions: [Vector3] = [.unitZ,.unitX,.unitY]
        for row in 0..<3 {
            let actual = result.rows[row]
            try require(actual.rowID == UInt64(row+11),"Original row identity")
            try require(actual.coefficients.count == fixture.names.count,"Complete original layout")
            for name in fixture.names { try near(actual.coefficients[try fixture.index(name)],authored[row][name,default: 0],"SI coefficient "+name) }
            try near(actual.velocityResidual,residual[row],"Original velocity residual")
            try near(actual.accelerationResidual,acceleration[row],"Original acceleration residual")
            try near(actual.accelerationBias,bias[row],"Original acceleration bias")
            try near(actual.drift,drift[row],"Original drift")
            try near(actual.velocityDecompositionResidual,0,"Original velocity replay")
            try near(actual.accelerationDecompositionResidual,0,"Original acceleration replay")
            try vector(actual.directionWorld,directions[row],"Physical direction")
        }
    }
    public static func straightDisk() throws(RollingRelationsQualificationError) {
        let fixture = try F(), state = try fixture.state(q: [1.25,-0.4,0,0],v: [1,0.2,0,2],a: [0.4,0.1,0.3,0.5])
        let result = try fixture.evaluate(state)
        try rows(result,fixture: fixture,normal: ["wheel-z":1],forward: ["wheel-x":1,"wheel-spin":-0.5],lateral: ["wheel-y":1],
                 residual: [0,0,0.2],acceleration: [0.3,0.15,0.1],bias: [0,0,0])
        try vector(result.contactPointWorld,F.vector(1.25,-0.4,0),"Supporting contact")
        try vector(result.contactTraceVelocityWorld,F.vector(1,0.2,0),"Reselected contact trace")
        try vector(result.relativeMaterialVelocityWorld,F.vector(0,0.2,0),"Material velocity")
        try vector(result.relativeMaterialVelocityRateWorld,F.vector(0.15,0.1,0.3),"Material derivative")
        try require(result.rank.rank == 3 && result.rank.independentRowIDs == [11,12,13],"Original full row rank")
        try require(result.modelStamp == fixture.model.stamp && result.sourceID == "rolling-source" && result.sourceRevision == 31 && result.referenceTime == 2.5 && result.time == 0,"Original provenance/clock")
        try require(result.worldFrame == fixture.model.tree.worldFrame && result.wheel.body == fixture.wheel && result.prescribedPlaneSourceID == nil,"Physical bindings")
        let spin = try fixture.evaluate(fixture.state(q: [1.25,-0.4,0,Double.pi/2],v: [1,0.2,0,2],a: [0.4,0.1,0.3,0.5]))
        try vector(spin.contactPointWorld,result.contactPointWorld,"World contact under spin")
        try vector(result.wheelContactPointLocal,F.vector(0,0,-0.5),"Initial material rim")
        try vector(spin.wheelContactPointLocal,F.vector(0.5,0,0),"Reselected material rim")
        let slip = try fixture.evaluate(fixture.state(q: [0,0,0,0],v: [1.4,0,0,2],a: [0,0,0,0]))
        try near(slip.rows[1].velocityResidual,0.4,"Slip preserved without velocity projection")
    }
    public static func camberProjection() throws(RollingRelationsQualificationError) {
        let fixture = try F(camber: true)
        let result = try fixture.evaluate(fixture.state(q: [0,0,0,0.7],v: [1,0,0,2],a: [0.4,0,0,0.5]))
        try vector(result.axisWorld,F.vector(0,0.6,0.8),"Cambered axle")
        try near(result.contactChartSine,0.6,"Normalized supporting chart")
        try vector(result.contactPointWorld,F.vector(0,0.4,0),"Cambered supporting contact")
        try rows(result,fixture: fixture,normal: ["wheel-z":1],forward: ["wheel-x":1,"wheel-spin":-0.5],lateral: ["wheel-y":1],
                 residual: [0,0,0],acceleration: [0,0.15,0],bias: [0,0,0])
    }
    public static func movingPlaneAndPower() throws(RollingRelationsQualificationError) {
        let fixture = try F(movingPlane: true)
        let q = [1.2,-0.4,0,0.3,0.25,0.8], v = [0.7,0.2,0,1.1,0.3,0.4], a = [0.1,-0.2,0.3,0.5,0.05,-0.15]
        let state = try fixture.state(q: q,v: v,a: a), bodyResult = try fixture.evaluate(state)
        let motion = try F.translated { try FrameMotion(pose: RigidTransform(rotation: try UnitQuaternion(axis: .unitZ,angle: q[5]),translation: F.vector(q[4],0,0)),
            velocity: SpatialMotion(angular: F.vector(0,0,v[5]),linear: F.vector(v[4],0,0)),
            acceleration: SpatialMotion(angular: F.vector(0,0,a[5]),linear: F.vector(a[4],0,0))) }
        let externalResult = try fixture.evaluate(state,relation: fixture.relation(prescribed: true),sample: fixture.sample(motion: motion))
        let planeVX = v[4]-v[5]*q[1], planeVY = v[5]*(q[0]-q[4])
        let residual = [0,v[0]-0.5*v[3]-planeVX,v[1]-planeVY]
        let acceleration = [a[2],a[0]-0.5*a[3]-a[4]+a[5]*q[1]+v[5]*v[1],a[1]-a[5]*(q[0]-q[4])-v[5]*(v[0]-v[4])]
        try rows(bodyResult,fixture: fixture,normal: ["wheel-z":1],forward: ["wheel-x":1,"wheel-spin":-0.5,"plane-x":-1,"plane-yaw":q[1]],
                 lateral: ["wheel-y":1,"plane-yaw":-(q[0]-q[4])],residual: residual,acceleration: acceleration,bias: [0,v[5]*v[1],-v[5]*(v[0]-v[4])])
        try rows(externalResult,fixture: fixture,normal: ["wheel-z":1],forward: ["wheel-x":1,"wheel-spin":-0.5],lateral: ["wheel-y":1],
                 residual: residual,acceleration: acceleration,bias: [0,-a[4]+a[5]*q[1]+v[5]*v[1],-a[5]*(q[0]-q[4])-v[5]*(v[0]-v[4])],drift: [0,-planeVX,-planeVY])
        try vector(bodyResult.planeMaterialVelocityWorld,F.vector(planeVX,planeVY,0),"Original plane material velocity")
        try vector(externalResult.relativeMaterialVelocityWorld,bodyResult.relativeMaterialVelocityWorld,"Prescribed/body physical equality")
        try require(externalResult.prescribedPlaneSourceID == "plane-law" && externalResult.prescribedPlaneSourceRevision == 7,"Prescribed source identity")
        let lambda = 2.5
        for result in [bodyResult,externalResult] {
            for row in result.rows {
                let physical = try F.translated {
                    let wheelPower = try row.wheelPower.linearDirection.dot(result.wheelMaterialVelocityWorld)
                    let planePower = try row.planePower.linearDirection.dot(result.planeMaterialVelocityWorld)
                    return lambda*(wheelPower+planePower)
                }
                var generalized = 0.0
                for i in state.state.v.indices { generalized += lambda*row.coefficients[i]*state.state.v[i] }
                try near(physical,lambda*row.velocityResidual,"Original endpoint power")
                try near(generalized+lambda*row.drift,physical,"Original generalized/prescribed power")
                try vector(row.wheelPower.pointWorld,result.contactPointWorld,"Physical force point")
                try vector(row.planePower.pointWorld,result.contactPointWorld,"Opposite endpoint force point")
                try vector(row.wheelPower.angularDirection,.zero,"No artificial wheel couple")
                try vector(row.planePower.angularDirection,.zero,"No artificial plane couple")
                try require(row.wheelPower.body == fixture.wheel && row.wheelPower.frame == fixture.wheelFrame && row.wheelPower.worldFrame == fixture.model.tree.worldFrame,"Wheel force provenance")
                let expectedBody: EntityID?
                if result.prescribedPlaneSourceID == nil { expectedBody = fixture.planeBody } else { expectedBody = nil }
                try require(row.planePower.body == expectedBody,"Plane generalized authority")
            }
        }
        let torque = try F.translated { try F.vector(0,0,-0.5).cross(bodyResult.rows[1].wheelPower.linearDirection.scaled(by: lambda)) }
        try near(torque.y,-0.5*lambda,"Physical spin moment")
    }
    private static func tiltedQuery(_ fixture: F,_ t: Double) throws(RollingRelationsQualificationError) -> RollingEvaluation {
        let omega = 0.4
        let state = try fixture.state(q: [0.7*t+0.05*t*t,0,0.1*t*t,2*t+0.15*t*t],v: [0.7+0.1*t,0,0.2*t,2+0.3*t],a: [0.1,0,0.2,0.3],time: t)
        let motion = try F.translated { try FrameMotion(pose: RigidTransform(rotation: try UnitQuaternion(axis: .unitY,angle: omega*t),translation: .zero),
            velocity: SpatialMotion(angular: F.vector(0,omega,0),linear: .zero),acceleration: FrameMotion.zeroMotion) }
        return try fixture.evaluate(state,relation: fixture.relation(prescribed: true),sample: fixture.sample(motion: motion,time: t))
    }
    public static func contactFirstDerivative() throws(RollingRelationsQualificationError) {
        let fixture = try F(), result = try tiltedQuery(fixture,0)
        try near(result.rows[0].accelerationResidual,0.68,"Independent rotating-normal gap second derivative")
        try near(result.rows[0].accelerationBias,0.48,"Independent rotating-normal acceleration bias")
        try near(result.rows[1].velocityResidual,-0.3,"Original forward material residual")
        try near(result.rows[1].accelerationResidual,-0.05,"Forward material derivative")
        try vector(result.contactTraceVelocityWorld,F.vector(0.5,0,0),"Supporting contact trace derivative")
        try vector(result.relativeMaterialVelocityRateWorld,F.vector(-0.05,0,0.8),"Transported material derivative")
        try vector(result.rows[0].directionRateWorld,F.vector(0.4,0,0),"Normal basis rate")
        try vector(result.rows[1].directionRateWorld,F.vector(0,0,-0.4),"Forward basis rate")
        let h = 1e-6, plus = try tiltedQuery(fixture,h), minus = try tiltedQuery(fixture,-h)
        for i in 0..<3 { try near((plus.rows[i].velocityResidual-minus.rows[i].velocityResidual)/(2*h),result.rows[i].accelerationResidual,"Actual chart residual first derivative",tolerance: 2e-7) }
    }
    public static func sourceAndContactRefusals() throws(RollingRelationsQualificationError) {
        let fixture = try F(), state = try fixture.state(q: [0,0,0,0],v: [0,0,0,0],a: [0,0,0,0])
        let other = try F(identity: "rolling-other"), stale = try other.state(q: [0,0,0,0],v: [0,0,0,0],a: [0,0,0,0])
        try expect({ if case .staleSource = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(stale) }
        let external = try fixture.relation(prescribed: true)
        for sample in [try fixture.sample(time: 0.1),try fixture.sample(revision: 8),try fixture.sample(stamp: other.model.stamp),try fixture.sample(frame: fixture.rootFrame)] {
            try expect({ if case .stalePlaneSample = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: external,sample: sample) }
        }
        try expect({ if case .stalePlaneSample = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: external) }
        try expect({ if case .unsupportedDomain = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(wheelFrame: fixture.rootFrame)) }
        try expect({ if case .unsupportedDomain = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(binding: .body(body: fixture.wheel,frame: fixture.wheelFrame,point: .zero,normal: .unitZ))) }
        try expect({ if case .unsupportedDomain = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(binding: .body(body: fixture.root,frame: fixture.wheelFrame,point: .zero,normal: .unitZ))) }
        try expect({ if case .unsupportedDomain = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(binding: .prescribed(frame: fixture.rootFrame,sourceID: "plane-law",sourceRevision: 7,point: .zero,normal: .unitZ)),sample: fixture.sample(frame: fixture.rootFrame)) }
        try expect({ if case .invalidInput = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(binding: .prescribed(frame: fixture.model.tree.worldFrame,sourceID: "plane-law",sourceRevision: 7,point: .zero,normal: .unitZ))) }
        try expect({ if case .invalidChart = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.evaluate(state,relation: fixture.relation(axis: .unitZ)) }
        for gap in [0.01,-0.02] {
            try expect({ if case .undefinedContact(let actual) = $0 { return abs(actual-gap) < 1e-10 }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
                _ = try fixture.evaluate(fixture.state(q: [0,0,gap,0],v: [0,0,0,0],a: [0,0,0,0]))
            }
        }
    }
    public static func rankAndWorkBounds() throws(RollingRelationsQualificationError) {
        let fixture = try F(), state = try fixture.state(q: [0,0,0,0],v: [0,0,0,0],a: [0,0,0,0]), relation = try fixture.relation(), policy = try fixture.policy()
        let evaluator: any RollingConstraintEvaluating = RollingConstraintEvaluator()
        var exact = try F.work(storage: 7296,operations: 139264)
        _ = try F.translated { try evaluator.evaluate(relation,state: state,prescribedPlane: nil,policy: policy,work: &exact) }
        try require(exact.peakScalarStorage == 7296 && exact.operations == 139264 && exact.iterations == 0,"Exact original work ledger")
        var short = try F.work(storage: 7295)
        try expect({ if case .numerical(.resourceLimit(resource: .scalarStorage,limit: 7295)) = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
            _ = try F.translated { try evaluator.evaluate(relation,state: state,prescribedPlane: nil,policy: policy,work: &short) }
        }
        try require(short.operations == 0 && short.peakScalarStorage == 0,"Failed storage reservation retained")
        var consumed = try F.work(operations: 3)
        try F.translated { try consumed.chargeOperations(3) }
        try expect({ if case .numerical(.resourceLimit(resource: .arithmeticOperations,limit: 3)) = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
            _ = try F.translated { try evaluator.evaluate(relation,state: state,prescribedPlane: nil,policy: policy,work: &consumed) }
        }
        try require(consumed.operations == 3 && consumed.peakScalarStorage == 7296,"Consumed work survives refusal")
        for limited in [try fixture.policy(bodies: 1),try fixture.policy(metadata: 1),try fixture.policy(scales: [],coordinates: 0),try fixture.policy(scales: [1])] {
            var work = try F.work()
            try expect({ if case .capacityExceeded = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
                _ = try F.translated { try evaluator.evaluate(relation,state: state,prescribedPlane: nil,policy: limited,work: &work) }
            }
            try require(work.operations == 0 && work.peakScalarStorage == 0,"Pre-work capacity refusal")
        }
        let scaled = try fixture.evaluate(state,policy: fixture.policy(scales: [0.1,10,2,0.5]))
        try require(scaled.rank.rank == 3,"Characteristic units preserve rank")
        try near(scaled.rows[1].coefficients[try fixture.index("wheel-spin")],-0.5,"Rank scaling preserves SI rows")
        let fixed = try F(fixedWheel: true), fixedState = try fixed.state(q: [],v: [],a: [])
        let result = try fixed.evaluate(fixedState,relation: fixed.relation(prescribed: true),sample: fixed.sample(),policy: fixed.policy(independent: false))
        try require(result.rank.rank == 0 && result.rank.independentRowIDs.isEmpty && result.rank.dependentRowIDs == [11,12,13] && result.rows.allSatisfy { $0.coefficients.isEmpty },"Original zero-coordinate rank report")
        try expect({ if case .rankDeficient(rank: 0,rows: 3) = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
            _ = try fixed.evaluate(fixedState,relation: fixed.relation(prescribed: true),sample: fixed.sample())
        }
    }
    public static func policyAndCancellation() throws(RollingRelationsQualificationError) {
        let fixture = try F()
        try expect({ if case .invalidInput = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.policy(contact: 0) }
        try expect({ if case .invalidInput = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.policy(chart: 1) }
        try expect({ if case .invalidInput = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in _ = try fixture.policy(scales: [1,1,1,0]) }
        let state = try fixture.state(q: [0,0,0,0],v: [0,0,0,0],a: [0,0,0,0])
        try cancellation(fixture: fixture,state: state,policy: fixture.policy(cancelled: { true }))
    }
    public static func cancellation(fixture: RollingRelationsQualificationFixtures,state: CompiledKinematicState,policy: RollingEvaluationPolicy) throws(RollingRelationsQualificationError) {
        let relation = try fixture.relation(), evaluator: any RollingConstraintEvaluating = RollingConstraintEvaluator()
        var work = try F.work()
        try expect({ if case .cancelled = $0 { return true }; return false }) { () throws(RollingRelationsQualificationError) -> Void in
            _ = try F.translated { try evaluator.evaluate(relation,state: state,prescribedPlane: nil,policy: policy,work: &work) }
        }
        try require(work.operations == 0 && work.peakScalarStorage == 0,"Cancellation precedes work")
    }
}
