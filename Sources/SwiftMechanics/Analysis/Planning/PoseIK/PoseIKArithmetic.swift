internal enum PoseIKArithmetic {
    static func check(_ policy: PoseIKPolicy) throws(PoseIKError) {
        guard !Task.isCancelled, !policy.isCancelled(), !policy.derivative.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(PoseIKError) {
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(PoseIKError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(PoseIKError) -> Int {
        do { return try NumericalWork.product(a, b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(PoseIKError) -> Int {
        do { return try NumericalWork.sum(a, b) } catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(PoseIKError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func geometry<T>(_ operation: () throws(CoreError) -> T) throws(PoseIKError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    static func skew(_ v: Vector3) throws(PoseIKError) -> Matrix3 {
        try geometry { () throws(CoreError) in try Matrix3(0, -v.z, v.y, v.z, 0, -v.x, -v.y, v.x, 0) }
    }
    static func vee(_ matrix: Matrix3) throws(PoseIKError) -> Vector3 {
        try geometry { () throws(CoreError) in try Vector3((matrix.m21-matrix.m12)/2, (matrix.m02-matrix.m20)/2, (matrix.m10-matrix.m01)/2) }
    }
    static func component(_ vector: Vector3, _ index: Int) -> Double {
        switch index { case 0: vector.x; case 1: vector.y; default: vector.z }
    }
    static func bridge(_ error: PoseIKError) -> NonlinearCause {
        switch error {
        case .outsideBounds, .orientationBranch: return .equation(.outsideDomain)
        case .numerical(let error): return .numerical(error)
        case .cancelled: return .numerical(.cancelled)
        case .derivatives(.numerical(let error)): return .numerical(error)
        case .derivatives(.cancelled): return .numerical(.cancelled)
        case .derivatives: return .equation(.invalidDerivative)
        case .nonFiniteResult: return .numerical(.nonFiniteResult)
        case .constraints: return .equation(.evaluationFailed(code: 330103))
        case .joints: return .equation(.evaluationFailed(code: 330106))
        case .core: return .equation(.evaluationFailed(code: 330102))
        default: return .equation(.evaluationFailed(code: 330100))
        }
    }
}
