import MechanicsCore
import MechanicsModel
import MechanicsNumerics
internal enum DifferentialArithmetic {
    static func checkpoint(_ policy: DerivativePolicy) throws(DerivativeError) {
        guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(DerivativeError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(DerivativeError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(DerivativeError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(DerivativeError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(DerivativeError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func finite(_ value: Double) throws(DerivativeError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func scalar(_ x: Double, _ dx: Double = 0) throws(DerivativeError) -> DirectionalScalar { try DirectionalScalar(value:x,direction:dx) }
    static func add(_ a: DirectionalScalar, _ b: DirectionalScalar, _ w: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        try charge(2,&w); return try scalar(a.value+b.value,a.direction+b.direction)
    }
    static func subtract(_ a: DirectionalScalar, _ b: DirectionalScalar, _ w: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        try charge(2,&w); return try scalar(a.value-b.value,a.direction-b.direction)
    }
    static func multiply(_ a: DirectionalScalar, _ b: DirectionalScalar, _ w: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        try charge(4,&w); return try scalar(a.value*b.value,a.direction*b.value+a.value*b.direction)
    }
    static func add(_ a: DifferentialVector, _ b: DifferentialVector, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialVector {
        try charge(6,&w); return try core { () throws(CoreError) in DifferentialVector(try a.value.adding(b.value),try a.direction.adding(b.direction)) }
    }
    static func subtract(_ a: DifferentialVector, _ b: DifferentialVector, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialVector {
        try charge(6,&w); return try core { () throws(CoreError) in DifferentialVector(try a.value.subtracting(b.value),try a.direction.subtracting(b.direction)) }
    }
    static func scale(_ a: DifferentialVector, _ b: DirectionalScalar, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialVector {
        try charge(12,&w); return try core { () throws(CoreError) in DifferentialVector(try a.value.scaled(by:b.value),try a.direction.scaled(by:b.value).adding(a.value.scaled(by:b.direction))) }
    }
    static func cross(_ a: DifferentialVector, _ b: DifferentialVector, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialVector {
        try charge(30,&w); return try core { () throws(CoreError) in DifferentialVector(try a.value.cross(b.value),try a.direction.cross(b.value).adding(a.value.cross(b.direction))) }
    }
    static func dot(_ a: DifferentialVector, _ b: DifferentialVector, _ w: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        try charge(16,&w); let pair=try core { () throws(CoreError) in
            let v=try a.value.dot(b.value), d=try a.direction.dot(b.value)+a.value.dot(b.direction)
            guard d.isFinite else { throw .nonFiniteResult }
            // Conversion is outside this Core-only closure below.
            return (v,d)
        }
        return try scalar(pair.0,pair.1)
    }
    static func apply(_ a: DifferentialMatrix, _ b: DifferentialVector, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialVector {
        try charge(48,&w); return try core { () throws(CoreError) in DifferentialVector(try a.value.applying(to:b.value),try a.direction.applying(to:b.value).adding(a.value.applying(to:b.direction))) }
    }
    static func multiply(_ a: DifferentialMatrix, _ b: DifferentialMatrix, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMatrix {
        try charge(144,&w); return try core { () throws(CoreError) in DifferentialMatrix(try a.value.multiplied(by:b.value),try a.direction.multiplied(by:b.value).adding(a.value.multiplied(by:b.direction))) }
    }
    static func transpose(_ a: DifferentialMatrix) -> DifferentialMatrix { DifferentialMatrix(a.value.transposed(),a.direction.transposed()) }
    static func hat(_ a: Vector3) throws(DerivativeError) -> Matrix3 {
        try core { () throws(CoreError) in try Matrix3(0,-a.z,a.y,a.z,0,-a.x,-a.y,a.x,0) }
    }
    static func rotation(_ q: UnitQuaternion, tangent: Vector3, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMatrix {
        try charge(200,&w)
        return try core { () throws(CoreError) in
            let r=try q.matrix(), h=try Matrix3(0,-tangent.z,tangent.y,tangent.z,0,-tangent.x,-tangent.y,tangent.x,0)
            return DifferentialMatrix(r,try r.multiplied(by:h))
        }
    }
    static func equal(_ a: Double, _ b: Double, _ p: DerivativePolicy, _ w: inout NumericalWork) throws(DerivativeError) {
        try charge(5,&w)
        let ok=try core { () throws(CoreError) in try p.tolerance.contains(error:a-b,scale:max(abs(a),abs(b))) }
        guard ok else { throw .primalMismatch }
    }
    static func equal(_ a: Vector3, _ b: Vector3, _ p: DerivativePolicy, _ w: inout NumericalWork) throws(DerivativeError) {
        try equal(a.x,b.x,p,&w); try equal(a.y,b.y,p,&w); try equal(a.z,b.z,p,&w)
    }
    static func identityBytes(_ id: EntityID, _ p: DerivativePolicy, _ w: inout NumericalWork) throws(DerivativeError) {
        for _ in id.key.utf8 { try checkpoint(p); try charge(1,&w) }
    }
}
