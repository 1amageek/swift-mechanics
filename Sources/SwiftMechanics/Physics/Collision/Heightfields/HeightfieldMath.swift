internal enum HeightfieldMath {
    static func core<Value>(_ operation: () throws(CoreError) -> Value) throws(HeightfieldError) -> Value {
        do { return try operation() } catch { throw .core(error) }
    }
    static func supplier<Value>(_ operation: () throws(CollisionError) -> Value) throws(HeightfieldError) -> Value {
        do { return try operation() } catch { throw .collision(error) }
    }
    static func finite(_ x: Double) throws(HeightfieldError) -> Double {
        guard x.isFinite else { throw .arithmeticFailure }; return x
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x,y,z) }
    }
    static func add(_ a: Vector3, _ b: Vector3) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try a.adding(b) }
    }
    static func sub(_ a: Vector3, _ b: Vector3) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func scale(_ a: Vector3, _ s: Double) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try a.scaled(by:s) }
    }
    static func divide(_ a: Vector3, _ s: Double) throws(HeightfieldError) -> Vector3 {
        guard s.isFinite, s > 0 else { throw .arithmeticFailure }
        return try vector(a.x/s,a.y/s,a.z/s)
    }
    static func dot(_ a: Vector3, _ b: Vector3) throws(HeightfieldError) -> Double {
        try core { () throws(CoreError) in try a.dot(b) }
    }
    static func cross(_ a: Vector3, _ b: Vector3) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try a.cross(b) }
    }
    static func norm(_ a: Vector3) throws(HeightfieldError) -> Double {
        try core { () throws(CoreError) in try a.magnitude() }
    }
    static func unit(_ a: Vector3) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try a.normalized() }
    }
    static func point(_ pose: RigidTransform, _ p: Vector3) throws(HeightfieldError) -> Vector3 {
        try core { () throws(CoreError) in try pose.transforming(point:p) }
    }
    static func charge(_ count: Int, _ work: inout CollisionWork) throws(HeightfieldError) {
        do { try work.charge(count) } catch { throw .collision(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(HeightfieldError) -> Int {
        try supplier { () throws(CollisionError) in try CollisionWork.sum(a,b) }
    }
    static func product(_ a: Int, _ b: Int) throws(HeightfieldError) -> Int {
        try supplier { () throws(CollisionError) in try CollisionWork.product(a,b) }
    }
    static func reserve(vertexCount: Int, work: inout CollisionWork) throws(HeightfieldError) {
        let slots = try sum(512,product(16,vertexCount))
        let records = try sum(16,product(2,vertexCount))
        do { try work.requireStorage(slots); try work.requireRecords(records) }
        catch { throw .collision(error) }
    }
    static func accept(_ residual: Double, _ tolerance: Double) throws(HeightfieldError) {
        guard residual.isFinite else { throw .arithmeticFailure }
        guard residual <= tolerance else { throw .originalResidual(value:residual,threshold:tolerance) }
    }
}
