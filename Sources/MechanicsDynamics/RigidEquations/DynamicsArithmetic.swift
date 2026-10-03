import MechanicsCore
import MechanicsNumerics
internal enum DynamicsArithmetic {
    static func finite(_ value: Double) throws(DynamicsError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func operations(_ count: Int, _ work: inout NumericalWork) throws(DynamicsError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(count) } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(DynamicsError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
    }
    static func product(_ a: Int, _ b: Int) throws(DynamicsError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
    }
    static func sum(_ a: Int, _ b: Int) throws(DynamicsError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(DynamicsError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func add(_ a: Vector3, _ b: Vector3, _ work: inout NumericalWork) throws(DynamicsError) -> Vector3 {
        try operations(3,&work); return try core { () throws(CoreError) in try a.adding(b) }
    }
    static func subtract(_ a: Vector3, _ b: Vector3, _ work: inout NumericalWork) throws(DynamicsError) -> Vector3 {
        try operations(3,&work); return try core { () throws(CoreError) in try a.subtracting(b) }
    }
    static func scale(_ a: Vector3, _ s: Double, _ work: inout NumericalWork) throws(DynamicsError) -> Vector3 {
        try operations(3,&work); return try core { () throws(CoreError) in try a.scaled(by:s) }
    }
    static func cross(_ a: Vector3, _ b: Vector3, _ work: inout NumericalWork) throws(DynamicsError) -> Vector3 {
        try operations(9,&work); return try core { () throws(CoreError) in try a.cross(b) }
    }
    static func dot(_ a: Vector3, _ b: Vector3, _ work: inout NumericalWork) throws(DynamicsError) -> Double {
        try operations(5,&work); return try core { () throws(CoreError) in try a.dot(b) }
    }
    static func apply(_ a: Matrix3, _ b: Vector3, _ work: inout NumericalWork) throws(DynamicsError) -> Vector3 {
        try operations(15,&work); return try core { () throws(CoreError) in try a.applying(to:b) }
    }
    static func rotation(_ q: UnitQuaternion, _ work: inout NumericalWork) throws(DynamicsError) -> Matrix3 {
        try operations(39,&work); return try core { () throws(CoreError) in try q.matrix() }
    }
    static func inertia(_ body: Matrix3, rotation r: Matrix3, _ work: inout NumericalWork) throws(DynamicsError) -> Matrix3 {
        try operations(90,&work); return try core { () throws(CoreError) in try r.multiplied(by:body).multiplied(by:r.transposed()) }
    }
}
