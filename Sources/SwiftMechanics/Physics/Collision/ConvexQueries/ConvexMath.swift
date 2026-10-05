internal enum ConvexMath {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ConvexCollisionError) -> T {
        do { return try body() } catch { throw .collision(.core(error)) }
    }
    static func collision<T>(_ body: () throws(CollisionError) -> T) throws(ConvexCollisionError) -> T {
        do { return try body() } catch { throw .collision(error) }
    }
    static func finite(_ x: Double) throws(ConvexCollisionError) -> Double {
        guard x.isFinite else { throw .collision(.arithmeticFailure) }; return x
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x, y, z) }
    }
    static func add(_ a: Vector3, _ b: Vector3) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try a.adding(b) }
    }
    static func sub(_ a: Vector3, _ b: Vector3) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func scale(_ a: Vector3, _ b: Double) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try a.scaled(by: b) }
    }
    static func dot(_ a: Vector3, _ b: Vector3) throws(ConvexCollisionError) -> Double {
        try core { () throws(CoreError) in try a.dot(b) }
    }
    static func cross(_ a: Vector3, _ b: Vector3) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try a.cross(b) }
    }
    static func norm(_ a: Vector3) throws(ConvexCollisionError) -> Double {
        try core { () throws(CoreError) in try a.magnitude() }
    }
    static func unit(_ a: Vector3) throws(ConvexCollisionError) -> Vector3 {
        try core { () throws(CoreError) in try a.normalized() }
    }
    static func charge(_ n: Int, _ work: inout CollisionWork) throws(ConvexCollisionError) {
        try collision { () throws(CollisionError) in try work.charge(n) }
    }
    static func storage(vertices: Int, faces: Int, edges: Int, work: inout CollisionWork) throws(ConvexCollisionError) {
        // Includes simultaneous staging arrays, projection matrices and owned output supports.
        let slots = try collision { () throws(CollisionError) in
            try CollisionWork.sum(512, CollisionWork.sum(CollisionWork.product(vertices, 48),
                CollisionWork.sum(CollisionWork.product(faces, 32), CollisionWork.product(edges, 16))))
        }
        try collision { () throws(CollisionError) in try work.requireStorage(slots) }
        let records = try collision { () throws(CollisionError) in
            try CollisionWork.sum(4, CollisionWork.sum(vertices, CollisionWork.sum(faces, edges)))
        }
        try collision { () throws(CollisionError) in try work.requireRecords(records) }
    }
    static func iterate(_ work: inout CollisionWork) throws(ConvexCollisionError) {
        do { try work.advanceIteration() }
        catch {
            if case .resourceLimit(resource: .iterations, limit: _) = error {
                throw .nonConvergence(iterations: work.iterations)
            }
            throw .collision(error)
        }
    }
}
