internal enum GranularAdmission {
    static func capacity(_ n: Int,_ m: Int,policy: GranularPolicy) throws(GranularError) {
        guard n <= policy.maximumParticles else { throw .capacity(resource:"particles",limit:policy.maximumParticles) }
        guard m <= policy.maximumBoundaries else { throw .capacity(resource:"boundaries",limit:policy.maximumBoundaries) }
    }
    static func proxy(_ proxy: CollisionProxy,body: ModelReference,frame: ModelReference,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.charge(32,policy:policy,work:&work)
        try GranularArithmetic.proxy(proxy,policy:policy,work:&work); try GranularArithmetic.key(body.id.key,policy:policy,work:&work)
        try GranularArithmetic.key(frame.id.key,policy:policy,work:&work)
        guard proxy.geometry.bodyID == body.id, proxy.geometry.frameID == frame.id, proxy.geometry.frameRevision == frame.revision,
            proxy.filter.enabled, !proxy.filter.isTrigger else { throw .invalidBinding }
    }
    static func distinct(_ a: CollisionProxy,_ b: CollisionProxy,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        try GranularArithmetic.charge(32,policy:policy,work:&work)
        try GranularArithmetic.key(a.geometry.colliderID.key,policy:policy,work:&work); try GranularArithmetic.key(b.geometry.colliderID.key,policy:policy,work:&work)
        try GranularArithmetic.key(a.geometry.bodyID.key,policy:policy,work:&work); try GranularArithmetic.key(b.geometry.bodyID.key,policy:policy,work:&work)
        guard a.geometry.colliderID != b.geometry.colliderID, a.geometry.bodyID != b.geometry.bodyID else { throw .invalidBinding }
    }
}
