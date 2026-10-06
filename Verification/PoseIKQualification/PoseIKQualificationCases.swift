import SwiftMechanics

public enum PoseIKQualificationCases {
    public typealias F = PoseIKQualificationFixtures
    public static func witness(_ result: PoseIKResult, problem: PoseIKProblem,
                               expected: [Double]? = nil) throws(PoseIKQualificationError) {
        try F.translated {
            try F.require(result.identity == problem.identity && result.source.identity == problem.identity && result.source.tree.revision == problem.tree.revision,
                "The public result must preserve the original query and mechanical source.")
            try F.require(result.source.layout.scales == problem.layout.scales && result.source.layout.coordinateIDs == problem.layout.coordinateIDs &&
                result.initialPositions == problem.initialPositions && result.referencePositions == problem.referencePositions && result.state.time == problem.time,
                "Coordinate scales, original positions and frozen query clock must remain attributable.")
            try F.require(result.original.isFeasible && result.original.rowRank?.rank == result.original.rowIDs.count,
                "Success requires original physical acceptance and independent full row rank.")
            try F.require(result.state.v.allSatisfy { $0 == 0 } && result.state.acceleration.allSatisfy { $0 == 0 }, "A query must not publish moving Runtime state.")
            if let expected { for i in expected.indices { try F.near(result.state.q[i], expected[i], "Original SI solution must match the independent coordinate oracle.") } }
            let snapshot = try TreeKinematicsEvaluator().evaluate(problem.tree, state: result.state, policy: F.policy().joint)
            for task in problem.tasks {
                switch task {
                case .point(_, let id, _, let local, let target, _, let tolerance):
                    let point = try snapshot.body(id).motion.pose.transforming(point: local)
                    try F.require(try point.subtracting(target).magnitude() <= tolerance, "Replayed original world point must satisfy metres tolerance.")
                case .orientation(_, let id, _, let target, _, let tolerance):
                    try rotation(try snapshot.body(id).motion.pose.rotation, target, tolerance)
                case .pose(_, let id, _, let local, let target, _, _, let tolerance, let matrixTolerance):
                    let pose = try snapshot.body(id).motion.pose
                    try F.require(try pose.transforming(point: local).subtracting(target.translation).magnitude() <= tolerance, "Replayed original pose point must satisfy metres tolerance.")
                    try rotation(pose.rotation, target.rotation, matrixTolerance)
                case .collision: throw PoseIKQualificationError.assertion("Collision tasks cannot produce a selected success.")
                }
            }
            for i in result.state.q.indices { try F.require(result.state.q[i] >= problem.minimumPositions[i] && result.state.q[i] <= problem.maximumPositions[i], "Original finite query bounds must hold.") }
            try F.require(result.work.operations > 0 && result.work.peakScalarStorage > 0 && result.work.operations <= result.work.budget.arithmeticOperations &&
                result.work.iterations <= result.work.budget.iterations && result.work.peakScalarStorage <= result.work.budget.scalarStorage,
                "Actual result work must be positive and remain within the original caller budget.")
        }
    }
    private static func rotation(_ actual: UnitQuaternion, _ target: UnitQuaternion, _ tolerance: Double) throws(PoseIKQualificationError) {
        try F.translated {
            let a = try actual.matrix(), b = try target.matrix()
            var squared = 0.0
            for r in 0..<3 { for c in 0..<3 { let e = try a.element(row: r, column: c)-b.element(row: r, column: c); squared += e*e } }
            try F.require(squared.squareRoot() <= tolerance, "Complete original rotation matrices must pass, not only the skew residual.")
        }
    }
    public static func cartesianPoints() throws(PoseIKQualificationError) {
        let model = try F.model(), q = [0.3, -0.2, 0.4], local = try F.translated { try Vector3(0.2, -0.1, 0.3) }
        let target = try F.target(q, local: local)
        let problem = try F.problem(model, tasks: [F.point(model, target: target.translation, local: local)])
        try witness(F.solve(problem), problem: problem, expected: q)
        try F.require(model.stamp.revision == F.revision && model.tree.worldFrame == problem.worldFrame && model.descriptor.identity == F.source,
            "The solution must consume the real compiler-admitted tree and source identity.")
    }
    public static func orientationAndPose() throws(PoseIKQualificationError) {
        let model = try F.model(rotating: true), q = [0.3, -0.2, 0.1, 0.12, -0.15, 0.18]
        let local = try F.translated { try Vector3(0.2, -0.1, 0.3) }, target = try F.target(q, local: local)
        let problem = try F.problem(model, tasks: [F.pose(model, target: target, local: local)])
        try witness(F.solve(problem), problem: problem, expected: q)
        let body = model.tree.bodies[model.tree.bodies.count-1]
        let orientation = PoseIKTask.orientation(rowIDs: [4, 5, 6], body: body.id, bodyFrame: body.frame,
            targetWorld: target.rotation, angularScale: 0.6, matrixTolerance: 2e-8)
        let orientationProblem = try F.problem(model, tasks: [orientation], reference: [0.2, -0.1, 0.3, 0, 0, 0])
        try witness(F.solve(orientationProblem), problem: orientationProblem, expected: [0.2, -0.1, 0.3, q[3], q[4], q[5]])
    }
    public static func redundantReference() throws(PoseIKQualificationError) {
        let model = try F.model(redundant: true), reference = [0.1, -0.2, 0.3, -0.1], scales = [0.5, 0.75, 1, 1.25]
        let total = 0.7, delta = total-reference[0]-reference[3]
        let q0 = reference[0]+delta*scales[0]*scales[0]/(scales[0]*scales[0]+scales[3]*scales[3])
        let expected = [q0, -0.2, 0.3, total-q0], target = try F.target(expected)
        let problem = try F.problem(model, tasks: [F.point(model, target: target.translation)], reference: reference, scales: scales)
        let result = try F.solve(problem)
        try witness(result, problem: problem, expected: expected)
        let n = expected.count, lambda = result.queryMultipliers
        try F.near((result.state.q[0]-reference[0])/scales[0]+lambda[1]*scales[0]/0.7, 0, "Normalized reference stationarity must use physical coordinate scales.")
        try F.near((result.state.q[n-1]-reference[n-1])/scales[n-1]+lambda[1]*scales[n-1]/0.7, 0, "Redundant coordinate stationarity must preserve the original query covector.")
    }
    public static func timedOriginalLoops() throws(PoseIKQualificationError) {
        let model = try F.model(redundant: true), expected = [0.2, -0.1, 0.3, 0.625], target = try F.target(expected)
        let initial = [0.05, 0, 0, 0.4], lower = [-2.0, -2, -2, 0.1], upper = [2.0, 2, 2, 1.2]
        let base = try F.problem(model, tasks: [F.point(model, target: target.translation)], initial: initial, reference: initial, lower: lower, upper: upper)
        let loop = try F.translated { try QuadraticConstraintSystem(layout: base.layout,
            rows: [QuadraticConstraint(id: 44, constant: -0.4, linear: [0, 0, 0, 0],
                hessian: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2], timeLinear: 0, timeQuadratic: 0, mixedTime: [0, 0, 0, 0.2])],
            minimumPosition: lower, maximumPosition: upper, minimumTime: 0, maximumTime: 8) }
        let problem = try F.problem(model, tasks: base.tasks, initial: initial, reference: initial, lower: lower, upper: upper, loops: loop)
        let result = try F.solve(problem)
        try witness(result, problem: problem, expected: expected)
        let x = result.state.q[3]/problem.layout.scales[3], tau = problem.time/problem.layout.timeScale
        try F.near(x*x+0.2*tau*x-0.4, 0, tolerance: 1e-9, "Original loop polynomial must use frozen physical time and coordinate scales.")
        try F.require(result.original.rowIDs == [1, 2, 3, 44] && result.original.loopRowIDs == [44] && result.source.loops?.rows[0].constant == -0.4,
            "Original loop rows and coefficients must be preserved rather than reduced or rewritten.")
        try PoseIKQualificationDerivatives.verify(problem, rotating: false, redundant: true)
    }
    public static func analyticDerivatives() throws(PoseIKQualificationError) {
        let model = try F.model(rotating: true), desired = [0.2, -0.1, 0.3, 0.1, -0.2, 0.15]
        let local = try F.translated { try Vector3(0.3, -0.2, 0.4) }, target = try F.target(desired, local: local)
        let problem = try F.problem(model, tasks: [F.pose(model, target: target, local: local)],
            initial: [0.1, 0.05, -0.2, -0.12, 0.16, -0.08])
        try PoseIKQualificationDerivatives.verify(problem, rotating: true)
        try witness(F.solve(problem), problem: problem, expected: desired)
    }
    public static func rankBranchAndBounds() throws(PoseIKQualificationError) {
        let model = try F.model(), root = model.tree.bodies[0]
        let task = F.point(model, target: try F.translated { try Vector3(1, -2, 0.5) }, bodyIndex: 0)
        let singular = try F.problem(model, tasks: [task])
        try F.refusal(singular) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in
            guard case .singularRows(rank: 0, rows: 3) = failure.cause else { throw .assertion("A solved singular initial query must fail the independent final rank gate.") }
            try F.require(failure.original?.isFeasible == false && failure.original?.rowRank?.rank == 0, "A rank-zero root point cannot become accepted evidence.")
        }
        try F.require(root.id == model.descriptor.root, "The singular fixture must query the real fixed root.")
        let six = try F.model(rotating: true)
        let original = try F.target([0, 0, 0, .pi, 0, 0])
        let branch = try F.problem(six, tasks: [F.pose(six, target: original)])
        try F.refusal(branch) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in
            guard case .orientationBranch(_, let cosine) = failure.cause else { throw .assertion("A false skew root at 180 degrees must be refused before nonlinear success.") }
            try F.near(cosine, -1, "The original full rotation must expose the excluded branch.")
        }
        let outsideTarget = try F.target([0.5, 0, 0])
        let bounded = try F.problem(model, tasks: [F.point(model, target: outsideTarget.translation)], upper: [0.1, 2, 2])
        try F.refusal(bounded) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in
            guard case .nonlinear(let nested) = failure.cause else { throw .assertion("A bound-blocked query must preserve the real nonlinear terminal cause.") }
            switch nested.cause {
            case .noAcceptableStep, .equation(.outsideDomain): break
            default: throw .assertion("The bound fixture must fail by actual domain/step refusal, not an unrelated numerical error.")
            }
            if let q = failure.lastPositions { try F.require(q[0] <= 0.1, "Failed query iterates must preserve original bounds.") }
            try F.require(failure.original?.isFeasible != true, "A failed bounded query must not assert a feasible candidate.")
        }
    }
    public static func sourceWorkAndCancellation() throws(PoseIKQualificationError) {
        let model = try F.model(), target = try F.target([0.2, -0.1, 0.3])
        let problem = try F.problem(model, tasks: [F.point(model, target: target.translation)])
        let stale = try F.problem(model, tasks: problem.tasks, revision: F.revision+1)
        try F.refusal(stale) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .staleIdentity = failure.cause else { throw .assertion("A stale coordinate source must fail before solving.") } }
        let shape = try F.problem(model, tasks: problem.tasks, initial: [])
        try F.refusal(shape) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .invalidShape = failure.cause else { throw .assertion("Invalid original coordinate shape must remain a typed failure.") } }
        let bounds = try F.problem(model, tasks: problem.tasks, initial: [3, 0, 0])
        try F.refusal(bounds) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .outsideBounds(coordinate: 100) = failure.cause else { throw .assertion("Out-of-box original coordinates must not be clamped.") } }
        let overflow = try F.problem(model, tasks: problem.tasks, initial: [1, 0, 0], scales: [Double.leastNonzeroMagnitude, 1, 1])
        try F.refusal(overflow) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .nonFiniteResult = failure.cause else { throw .assertion("Original coordinate normalization overflow cannot become a candidate.") } }
        let unsupported = try F.problem(model, tasks: problem.tasks, branch: .enumerateBranches)
        try F.refusal(unsupported) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .unsupportedBranch = failure.cause else { throw .assertion("Unsupported branch enumeration must remain an explicit refusal.") } }
        let collision = try F.problem(model, tasks: [.collision(rowIDs: [1, 2, 3])])
        try F.refusal(collision) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .unsupportedTask = failure.cause else { throw .assertion("Unsupported collision execution must not substitute zero task rows.") } }
        let overdetermined = try F.problem(model, tasks: [.pose(rowIDs: [1, 2, 3, 4, 5, 6], body: model.tree.bodies[3].id,
            bodyFrame: model.tree.bodies[3].frame, localPoint: .zero, targetWorld: target, lengthScale: 1, angularScale: 1,
            toleranceMeters: 1e-8, matrixTolerance: 1e-8)])
        try F.refusal(overdetermined) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .unsupportedTaskCount(rows: 6, coordinates: 3) = failure.cause else { throw .assertion("Overdetermined rows must remain intact and explicitly refused.") } }
        for resource in 0..<3 {
            let policy = try F.policy(storage: resource == 0 ? 16 : 2_000_000,
                operations: resource == 1 ? 1 : 100_000_000, iterations: resource == 2 ? 0 : 3000)
            try F.refusal(problem, policy: policy) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in
                let error: NumericalError
                switch failure.cause { case .numerical(let e): error = e
                case .nonlinear(let nested): guard case .numerical(let e) = nested.cause else { throw .assertion("Budget exhaustion must remain a real numerical failure.") }; error = e
                default: throw .assertion("Budget exhaustion cannot become an unrelated refusal.") }
                guard case .resourceLimit(let actual, _) = error else { throw .assertion("The original caller budget must be enforced.") }
                let expected: NumericalResource = resource == 0 ? .scalarStorage : (resource == 1 ? .arithmeticOperations : .iterations)
                try F.require(actual == expected && failure.work.operations <= policy.budget.arithmeticOperations && failure.work.iterations <= policy.budget.iterations,
                    "Failure must preserve the exact exhausted resource and consumed work bounds.")
            }
        }
        try F.refusal(problem, policy: F.policy(calls: 1)) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .capacityExceeded = failure.cause else { throw .assertion("Derivative supplier-call capacity must fail before execution.") } }
        for derivative in [false, true] {
            let policy = try F.policy(cancel: { !derivative }, derivativeCancel: { derivative })
            try F.refusal(problem, policy: policy) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in guard case .cancelled = failure.cause else { throw .assertion("Caller or derivative cancellation must preserve the original typed cancellation.") } }
        }
        try witness(F.solve(problem), problem: problem, expected: [0.2, -0.1, 0.3])
    }
    public static func actualNativeCancellation(_ problem: PoseIKProblem, policy: PoseIKPolicy) throws(PoseIKQualificationError) {
        try F.require(Task.isCancelled, "The Native cancellation witness must execute inside a genuinely cancelled Task.")
        try F.refusal(problem, policy: policy) { (failure: PoseIKFailure) throws(PoseIKQualificationError) -> Void in
            guard case .cancelled = failure.cause else { throw .assertion("A cancelled Native Task must not publish a candidate.") }
            try F.require(failure.work.operations == 0, "Entry cancellation must stop before numerical admission work.")
        }
    }
}
