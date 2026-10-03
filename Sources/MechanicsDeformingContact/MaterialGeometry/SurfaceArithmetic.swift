import MechanicsCore
import MechanicsNumerics
internal enum SurfaceArithmetic {
    static func core<T>(_ f: () throws(CoreError) -> T) throws(DeformingContactError) -> T { do { return try f() } catch { throw .core(error) } }
    static func numerical<T>(_ f: () throws(NumericalError) -> T) throws(DeformingContactError) -> T { do { return try f() } catch { throw .numerical(error) } }
    static func check(_ p: DeformingContactPolicy) throws(DeformingContactError) { guard !p.isCancelled(), !Task.isCancelled else { throw .cancelled } }
    static func charge(_ n: Int, _ p: DeformingContactPolicy, _ w: inout NumericalWork) throws(DeformingContactError) { try check(p); try numerical { () throws(NumericalError) in try w.chargeOperations(n) } }
    static func text(_ s: String, _ p: DeformingContactPolicy, _ w: inout NumericalWork) throws(DeformingContactError) {
        var count=0
        for _ in s.utf8 { try charge(2,p,&w); guard count < p.maximumIdentifierBytes else { throw .capacityExceeded }; count += 1 }
    }
    static func finite(_ x: Double) throws(DeformingContactError) -> Double { guard x.isFinite else { throw .nonFinite }; return x }
}
