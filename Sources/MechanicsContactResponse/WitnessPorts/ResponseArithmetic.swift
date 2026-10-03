import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCollision
internal enum ResponseArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ContactResponseError) -> T { do { return try body() } catch { throw .core(error) } }
    static func check(_ policy: ContactResponsePolicy) throws(ContactResponseError) { guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled } }
    static func charge(_ n: Int, _ work: inout NumericalWork) throws(ContactResponseError) { guard !Task.isCancelled else { throw .cancelled }; do { try work.chargeOperations(n) } catch { throw .numerical(error) } }
    static func storage(_ n: Int, _ work: inout NumericalWork) throws(ContactResponseError) { do { try work.requireStorage(n) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(ContactResponseError) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func sum(_ a: Int,_ b: Int) throws(ContactResponseError) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func finite(_ x: Double) throws(ContactResponseError) -> Double { guard x.isFinite else { throw .nonFiniteResult }; return x }
    static func key(_ key: String, policy: ContactResponsePolicy, work: inout NumericalWork) throws(ContactResponseError) {
        var iterator=key.utf8.makeIterator()
        while true { try check(policy); try charge(2,&work); guard iterator.next() != nil else { return } }
    }
    static func id(_ a: EntityID,_ b: EntityID, policy: ContactResponsePolicy, work: inout NumericalWork) throws(ContactResponseError) -> Bool {
        try charge(1,&work); guard a.kind == b.kind else { return false }
        try key(a.key,policy:policy,work:&work); try key(b.key,policy:policy,work:&work); return a == b
    }
    static func geometry(_ a: CollisionGeometryIdentity,_ b: CollisionGeometryIdentity, policy: ContactResponsePolicy, work: inout NumericalWork) throws(ContactResponseError) -> Bool {
        let collider=try id(a.colliderID,b.colliderID,policy:policy,work:&work), body=try id(a.bodyID,b.bodyID,policy:policy,work:&work), frame=try id(a.frameID,b.frameID,policy:policy,work:&work)
        try key(a.representation.assetKey,policy:policy,work:&work); try key(b.representation.assetKey,policy:policy,work:&work)
        try key(a.representation.provenance.source,policy:policy,work:&work); try key(b.representation.provenance.source,policy:policy,work:&work)
        try charge(32,&work)
        return collider && body && frame && a == b
    }
    static func add(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(ContactResponseError) -> Vector3 { try charge(3,&w); return try core { () throws(CoreError) in try a.adding(b) } }
    static func sub(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(ContactResponseError) -> Vector3 { try charge(3,&w); return try core { () throws(CoreError) in try a.subtracting(b) } }
    static func cross(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(ContactResponseError) -> Vector3 { try charge(9,&w); return try core { () throws(CoreError) in try a.cross(b) } }
    static func scale(_ a: Vector3,_ b: Double,_ w: inout NumericalWork) throws(ContactResponseError) -> Vector3 { try charge(3,&w); return try core { () throws(CoreError) in try a.scaled(by:b) } }
    static func dot(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(ContactResponseError) -> Double { try charge(5,&w); return try core { () throws(CoreError) in try a.dot(b) } }
    static func norm(_ a: Vector3,_ w: inout NumericalWork) throws(ContactResponseError) -> Double { try charge(2,&w); return try core { () throws(CoreError) in try a.magnitude() } }
    static func samePose(_ a: RigidTransform,_ b: RigidTransform, policy: ContactResponsePolicy,work: inout NumericalWork) throws(ContactResponseError) -> Bool {
        let distance=try norm(sub(a.translation,b.translation,&work),&work)
        try charge(9,&work)
        let q=a.rotation,r=b.rotation, error=abs(1-abs(q.w*r.w+q.x*r.x+q.y*r.y+q.z*r.z))
        return distance <= policy.lengthTolerance && error <= policy.normalTolerance
    }
    static func placement(_ body: RigidTransform,_ local: RigidTransform, proxy: RigidTransform, policy: ContactResponsePolicy,work: inout NumericalWork) throws(ContactResponseError) -> Bool {
        try charge(78,&work)
        let rb=try core { () throws(CoreError) in try body.rotation.matrix() }, rl=try core { () throws(CoreError) in try local.rotation.matrix() }
        try charge(45,&work); let expected=try core { () throws(CoreError) in try rb.multiplied(by:rl) }
        try charge(39,&work); let rp=try core { () throws(CoreError) in try proxy.rotation.matrix() }
        try charge(9,&work); let error=try core { () throws(CoreError) in try expected.subtracting(rp) }.maximumMagnitude
        try charge(15,&work); let offset=try core { () throws(CoreError) in try rb.applying(to:local.translation) }
        let distance=try norm(sub(add(body.translation,offset,&work),proxy.translation,&work),&work)
        return error <= policy.normalTolerance && distance <= policy.lengthTolerance
    }
}
