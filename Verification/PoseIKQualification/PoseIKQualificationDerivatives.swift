@testable import SwiftMechanics

public enum PoseIKQualificationDerivatives {
    public static func originalValues(_ problem: PoseIKProblem, x: [Double], rotating: Bool,
                                      redundant: Bool) throws(PoseIKQualificationError) -> [Double] {
        try PoseIKQualificationFixtures.translated {
            let q = zip(x, problem.layout.scales).map { $0.0*$0.1 }
            var result: [Double] = []
            func point(_ local: Vector3, _ target: Vector3, _ scale: Double) {
                let p = PoseIKQualificationOracle.point(q, local: [local.x, local.y, local.z], rotating: rotating, redundant: redundant)
                result.append(contentsOf: [(p[0]-target.x)/scale, (p[1]-target.y)/scale, (p[2]-target.z)/scale])
            }
            func orientation(_ target: UnitQuaternion, _ scale: Double) throws(CoreError) {
                let r = PoseIKQualificationOracle.rotation(rotating ? Array(q[3..<6]) : [0, 0, 0])
                let t = try target.matrix()
                let rt = [t.m00, t.m10, t.m20, t.m01, t.m11, t.m21, t.m02, t.m12, t.m22]
                let e = PoseIKQualificationOracle.multiply(rt, r)
                result.append(contentsOf: [(e[7]-e[5])/(2*scale), (e[2]-e[6])/(2*scale), (e[3]-e[1])/(2*scale)])
            }
            for task in problem.tasks {
                switch task {
                case .point(_, _, _, let local, let target, let scale, _): point(local, target, scale)
                case .orientation(_, _, _, let target, let scale, _): try orientation(target, scale)
                case .pose(_, _, _, let local, let target, let length, let angle, _, _):
                    point(local, target.translation, length); try orientation(target.rotation, angle)
                case .collision: throw PoseIKQualificationError.assertion("The derivative oracle admits only original selected task rows.")
                }
            }
            if let loops = problem.loops {
                let tau = problem.time/problem.layout.timeScale, n = q.count
                for row in loops.rows {
                    var f = row.constant+row.timeLinear*tau+0.5*row.timeQuadratic*tau*tau
                    for i in 0..<n {
                        f += row.linear[i]*x[i]+row.mixedTime[i]*tau*x[i]
                        for j in 0..<n { f += 0.5*x[i]*row.hessian[i*n+j]*x[j] }
                    }
                    result.append(f)
                }
            }
            return result
        }
    }
    public static func verify(_ problem: PoseIKProblem, rotating: Bool, redundant: Bool = false) throws(PoseIKQualificationError) {
        try PoseIKQualificationFixtures.translated {
            let policy = try PoseIKQualificationFixtures.policy()
            var work = NumericalWork(budget: policy.budget)
            let admission = try PoseIKAdmission(problem, policy: policy, work: &work)
            let n = problem.layout.scales.count, m = admission.rows.count, d = admission.solverCount
            var point = zip(problem.initialPositions, problem.layout.scales).map { $0.0/$0.1 }
            let lambda = (0..<m).map { 0.2-0.07*Double($0) }
            point.append(contentsOf: lambda)
            let provider = PoseIKEquations(admission: admission)
            let sample = try PoseIKTaskEvaluator(admission: admission).evaluate(point, original: true, work: &work)
            let original = try originalValues(problem, x: Array(point[..<n]), rotating: rotating, redundant: redundant)
            for r in 0..<m { try PoseIKQualificationFixtures.near(sample.values[r], original[r], tolerance: 2e-10, "Original task residual must match independent SI geometry.") }
            var matrix = [Double](repeating: .nan, count: d*d)
            try provider.jacobian(at: point, into: &matrix, work: &work)
            let firstStep = 2e-6, secondStep = 2e-4
            func values(_ x: [Double]) throws(PoseIKQualificationError) -> [Double] {
                try originalValues(problem, x: Array(x[..<n]), rotating: rotating, redundant: redundant)
            }
            func contracted(_ x: [Double]) throws(PoseIKQualificationError) -> Double {
                let f = try values(x)
                return zip(lambda, f).reduce(0) { $0+$1.0*$1.1 }
            }
            let center = try contracted(point)
            for k in 0..<n {
                var plus = point, minus = point
                plus[k] += firstStep; minus[k] -= firstStep
                let fp = try values(plus), fm = try values(minus)
                for r in 0..<m {
                    let fd = (fp[r]-fm[r])/(2*firstStep)
                    try PoseIKQualificationFixtures.near(sample.jacobian[r*n+k], fd, tolerance: 2e-7, "Analytic task Jacobian must match independent original differences.")
                    try PoseIKQualificationFixtures.near(matrix[(n+r)*d+k], fd, tolerance: 2e-7, "KKT lower block must preserve every task row.")
                    try PoseIKQualificationFixtures.near(matrix[k*d+n+r], fd, tolerance: 2e-7, "KKT transpose block must preserve every task row.")
                }
                for j in 0..<n {
                    let second: Double
                    if j == k {
                        var p = point, a = point; p[k] += secondStep; a[k] -= secondStep
                        second = (try contracted(p)-2*center+contracted(a))/(secondStep*secondStep)
                    } else {
                        var pp = point, pm = point, mp = point, mm = point
                        pp[j] += secondStep; pp[k] += secondStep
                        pm[j] += secondStep; pm[k] -= secondStep
                        mp[j] -= secondStep; mp[k] += secondStep
                        mm[j] -= secondStep; mm[k] -= secondStep
                        second = (try contracted(pp)-contracted(pm)-contracted(mp)+contracted(mm))/(4*secondStep*secondStep)
                    }
                    try PoseIKQualificationFixtures.near(matrix[j*d+k]-(j == k ? 1 : 0), second, tolerance: 3e-6,
                        "Actual tangent Hessian contraction must match independent physical second differences.")
                    try PoseIKQualificationFixtures.near(matrix[j*d+k], matrix[k*d+j], tolerance: 2e-9, "Actual Hessian must be symmetric.")
                }
            }
            for i in n..<d { for j in n..<d { try PoseIKQualificationFixtures.near(matrix[i*d+j], 0, tolerance: 0, "Equality KKT multiplier block must remain zero.") } }
            try PoseIKQualificationFixtures.require(work.operations > 0 && work.iterations >= n && work.peakScalarStorage > 0,
                "Actual tangent supplier and callback work must be charged.")
        }
    }
}
