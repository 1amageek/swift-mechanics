import MechanicsCore
import MechanicsModel
import MechanicsNumerics
internal enum FlexibleArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(FlexibleError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(FlexibleError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func sameIdentity(_ left: EntityID, _ right: EntityID, isCancelled: @Sendable () -> Bool, work: inout NumericalWork) throws(FlexibleError) -> Bool {
        guard !isCancelled() else { throw .cancelled }
        try charge(1,&work)
        guard left.kind == right.kind else { return false }
        try accountKey(left.key,isCancelled:isCancelled,work:&work)
        try accountKey(right.key,isCancelled:isCancelled,work:&work)
        guard !isCancelled(), !Task.isCancelled else { throw .cancelled }
        // Preserve the producer's canonical Unicode identity semantics after bounded admission.
        return left == right
    }
    private static func accountKey(_ key: String, isCancelled: @Sendable () -> Bool, work: inout NumericalWork) throws(FlexibleError) {
        var iterator = key.utf8.makeIterator()
        while true {
            guard !isCancelled() else { throw .cancelled }
            // Reserve traversal and semantic comparison units before advancing the borrowed view.
            try charge(2,&work)
            guard iterator.next() != nil else { return }
        }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(FlexibleError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(FlexibleError) { _ = try multiply(a,b) }
    static func multiply(_ a: Int, _ b: Int) throws(FlexibleError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(FlexibleError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func finite(_ x: Double) throws(FlexibleError) -> Double { guard x.isFinite else { throw .nonFiniteResult }; return x }
    static func subtract(_ a: Vector3, _ b: Vector3, _ work: inout NumericalWork) throws(FlexibleError) -> Vector3 {
        try charge(3,&work); return try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func edges(_ positions: [Vector3], _ indexes: [Int], _ work: inout NumericalWork) throws(FlexibleError) -> Matrix3 {
        let a = try subtract(positions[indexes[1]],positions[indexes[0]],&work)
        let b = try subtract(positions[indexes[2]],positions[indexes[0]],&work)
        let c = try subtract(positions[indexes[3]],positions[indexes[0]],&work)
        return try core { () throws(CoreError) in try Matrix3(a.x,b.x,c.x,a.y,b.y,c.y,a.z,b.z,c.z) }
    }
    static func component(_ v: Vector3, _ axis: Int) -> Double { switch axis { case 0: return v.x; case 1: return v.y; default: return v.z } }
}
