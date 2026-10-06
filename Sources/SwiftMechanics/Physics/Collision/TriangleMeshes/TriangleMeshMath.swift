internal enum TriangleMeshMath {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(TriangleMeshError) -> T {
        do { return try body() } catch { throw .collision(.core(error)) }
    }
    static func collision<T>(_ body: () throws(CollisionError) -> T) throws(TriangleMeshError) -> T {
        do { return try body() } catch { throw .collision(error) }
    }
    static func finite(_ value: Double) throws(TriangleMeshError) -> Double {
        guard value.isFinite else { throw .collision(.arithmeticFailure) }; return value
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x, y, z) }
    }
    static func add(_ a: Vector3, _ b: Vector3) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try a.adding(b) }
    }
    static func sub(_ a: Vector3, _ b: Vector3) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func scale(_ a: Vector3, _ b: Double) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try a.scaled(by: b) }
    }
    static func dot(_ a: Vector3, _ b: Vector3) throws(TriangleMeshError) -> Double {
        try core { () throws(CoreError) in try a.dot(b) }
    }
    static func cross(_ a: Vector3, _ b: Vector3) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try a.cross(b) }
    }
    static func norm(_ a: Vector3) throws(TriangleMeshError) -> Double {
        try core { () throws(CoreError) in try a.magnitude() }
    }
    static func unit(_ a: Vector3) throws(TriangleMeshError) -> Vector3 {
        try core { () throws(CoreError) in try a.normalized() }
    }
    static func coordinate(_ v: Vector3, _ axis: Int) -> Double { axis == 0 ? v.x : (axis == 1 ? v.y : v.z) }
    static func charge(_ count: Int, _ work: inout CollisionWork) throws(TriangleMeshError) {
        try collision { () throws(CollisionError) in try work.charge(count) }
    }
    static func storage(vertices: Int, faces: Int, work: inout CollisionWork) throws(TriangleMeshError) {
        let slots = try collision { () throws(CollisionError) in
            try CollisionWork.sum(1024, CollisionWork.sum(CollisionWork.product(vertices, 16), CollisionWork.product(faces, 128)))
        }
        try collision { () throws(CollisionError) in try work.requireStorage(slots) }
        let records = try collision { () throws(CollisionError) in
            try CollisionWork.sum(8, CollisionWork.sum(vertices, CollisionWork.product(faces, 8)))
        }
        try collision { () throws(CollisionError) in try work.requireRecords(records) }
    }
    static func iterate(_ work: inout CollisionWork) throws(TriangleMeshError) {
        do { try work.advanceIteration() } catch {
            if case .resourceLimit(resource: .iterations, limit: _) = error { throw .nonConvergence(iterations: work.iterations) }
            throw .collision(error)
        }
    }
}
