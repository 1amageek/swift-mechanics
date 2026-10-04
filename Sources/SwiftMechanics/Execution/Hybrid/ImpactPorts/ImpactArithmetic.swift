
internal enum ImpactArithmetic {
    static func numerical<T>(_ operation: () throws(NumericalError) -> T) throws(HybridError) -> T {
        do { return try operation() } catch { throw .numerical(error) }
    }
    static func core<T>(_ operation: () throws(CoreError) -> T) throws(HybridError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    static func finite(_ value: Double) throws(HybridError) -> Double { guard value.isFinite else { throw .nonFinite }; return value }
    static func point(_ motion: SpatialMotion, offset: Vector3) throws(HybridError) -> Vector3 {
        try core { () throws(CoreError) in try motion.linear.adding(motion.angular.cross(offset)) }
    }
    static func samePose(_ a: RigidTransform, _ b: RigidTransform, policy: HybridPolicy) throws(HybridError) -> Bool {
        guard try core({ () throws(CoreError) in try a.translation.subtracting(b.translation).magnitude() }) <= policy.lengthTolerance else { return false }
        for axis in [Vector3.unitX,Vector3.unitY,Vector3.unitZ] {
            if try core({ () throws(CoreError) in try a.transforming(direction:axis).subtracting(b.transforming(direction:axis)).magnitude() }) > policy.normalTolerance { return false }
        }
        return true
    }
    static func dot(_ a: [Double], _ b: [Double], work: inout NumericalWork) throws(HybridError) -> Double {
        guard a.count == b.count else { throw .invalidInput }
        try numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(2,a.count)) }
        var value=0.0
        for i in a.indices { value=try finite(value+a[i]*b[i]) }
        return value
    }
}
