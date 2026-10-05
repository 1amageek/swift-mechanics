internal enum ArticulatedArithmetic {
    static func check(_ policy: ArticulatedDynamicsPolicy) throws(ArticulatedDynamicsFailure) {
        guard !Task.isCancelled, !policy.admission.isCancelled() else { throw ArticulatedDynamicsFailure(.cancelled) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(ArticulatedDynamicsFailure) {
        do { try work.chargeOperations(count) } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(ArticulatedDynamicsFailure) {
        do { try work.requireStorage(count) } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
    }
    static func product(_ a: Int, _ b: Int) throws(ArticulatedDynamicsFailure) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
    }
    static func sum(_ a: Int, _ b: Int) throws(ArticulatedDynamicsFailure) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw ArticulatedDynamicsFailure(.numerical(error)) }
    }
    static func finite(_ value: Double) throws(ArticulatedDynamicsFailure) -> Double {
        guard value.isFinite else { throw ArticulatedDynamicsFailure(.nonFiniteResult) }; return value
    }
    static func core<Value>(_ operation: () throws(CoreError) -> Value) throws(ArticulatedDynamicsFailure) -> Value {
        do { return try operation() } catch { throw ArticulatedDynamicsFailure(.core(error)) }
    }
    static func vector(_ value: SpatialMotion) -> [Double] {
        [value.angular.x,value.angular.y,value.angular.z,value.linear.x,value.linear.y,value.linear.z]
    }
    static func vector(_ value: SpatialWrench) -> [Double] {
        [value.torque.x,value.torque.y,value.torque.z,value.force.x,value.force.y,value.force.z]
    }
    static func close(_ a: Vector3, _ b: Vector3, tolerance: NumericalTolerance) throws(ArticulatedDynamicsFailure) -> Bool {
        try core { () throws(CoreError) in
            guard try tolerance.contains(error:a.x-b.x,scale:max(abs(a.x),abs(b.x))) else { return false }
            guard try tolerance.contains(error:a.y-b.y,scale:max(abs(a.y),abs(b.y))) else { return false }
            return try tolerance.contains(error:a.z-b.z,scale:max(abs(a.z),abs(b.z)))
        }
    }
    static func dot(_ a: [Double], _ b: [Double], work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> Double {
        guard a.count == b.count else { throw ArticulatedDynamicsFailure(.invalidShape) }
        var result = 0.0
        for i in a.indices { try charge(2,&work); result = try finite(result+a[i]*b[i]) }
        return result
    }
    static func threshold(_ tolerance: NumericalTolerance, scale: Double, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> Double {
        try charge(2,&work); return try finite(tolerance.absolute+tolerance.relative*scale)
    }
}
