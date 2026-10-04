internal enum GranularArithmetic {
    static func check(_ policy: GranularPolicy) throws(GranularError) { guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled } }
    static func charge(_ count: Int, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) {
        try check(policy); do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, work: inout NumericalWork) throws(GranularError) { do { try work.requireStorage(count) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(GranularError) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func addCount(_ a: Int,_ b: Int) throws(GranularError) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func finite(_ x: Double) throws(GranularError) -> Double { guard x.isFinite else { throw .arithmeticFailure }; return x }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(GranularError) -> T { do { return try body() } catch { throw .core(error) } }
    static func add(_ a: Vector3,_ b: Vector3) throws(GranularError) -> Vector3 { try core { () throws(CoreError) in try a.adding(b) } }
    static func sub(_ a: Vector3,_ b: Vector3) throws(GranularError) -> Vector3 { try core { () throws(CoreError) in try a.subtracting(b) } }
    static func scale(_ a: Vector3,_ s: Double) throws(GranularError) -> Vector3 { try core { () throws(CoreError) in try a.scaled(by:s) } }
    static func cross(_ a: Vector3,_ b: Vector3) throws(GranularError) -> Vector3 { try core { () throws(CoreError) in try a.cross(b) } }
    static func dot(_ a: Vector3,_ b: Vector3) throws(GranularError) -> Double { try core { () throws(CoreError) in try a.dot(b) } }
    static func norm(_ a: Vector3) throws(GranularError) -> Double { try core { () throws(CoreError) in try a.magnitude() } }
    static func key(_ key: String, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) {
        for _ in key.utf8 { try charge(2,policy:policy,work:&work) }
    }
    static func proxy(_ proxy: CollisionProxy, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) {
        try key(proxy.geometry.bodyID.key,policy:policy,work:&work); try key(proxy.geometry.colliderID.key,policy:policy,work:&work)
        try key(proxy.geometry.frameID.key,policy:policy,work:&work); try key(proxy.geometry.representation.assetKey,policy:policy,work:&work)
        try key(proxy.geometry.representation.provenance.source,policy:policy,work:&work)
    }
}
