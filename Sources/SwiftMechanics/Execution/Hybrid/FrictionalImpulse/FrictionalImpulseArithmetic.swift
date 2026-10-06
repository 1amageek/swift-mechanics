internal enum FrictionalImpulseArithmetic {
    static func check(_ policy: FrictionalImpulsePolicy) throws(FrictionalImpulseFailure) {
        guard !Task.isCancelled, !policy.isCancelled(), !policy.admission.isCancelled() else { throw FrictionalImpulseFailure(.cancelled) }
    }
    static func numerical<Value>(_ operation: () throws(NumericalError) -> Value) throws(FrictionalImpulseFailure) -> Value {
        do { return try operation() } catch { throw FrictionalImpulseFailure(.numerical(error)) }
    }
    static func core<Value>(_ operation: () throws(CoreError) -> Value) throws(FrictionalImpulseFailure) -> Value {
        do { return try operation() } catch { throw FrictionalImpulseFailure(.core(error)) }
    }
    static func source<Value>(_ operation: () throws -> Value) throws(FrictionalImpulseFailure) -> Value {
        do { return try operation() }
        catch let error as JointError { throw FrictionalImpulseFailure(.joints(error)) }
        catch let error as CoreError { throw FrictionalImpulseFailure(.core(error)) }
        catch { throw FrictionalImpulseFailure(.unexpectedSupplierFailure) }
    }
    static func finite(_ value: Double) throws(FrictionalImpulseFailure) -> Double {
        guard value.isFinite else { throw FrictionalImpulseFailure(.nonFiniteResult) }; return value
    }
    static func product(_ a: Int, _ b: Int) throws(FrictionalImpulseFailure) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.product(a,b) } }
    static func sum(_ a: Int, _ b: Int) throws(FrictionalImpulseFailure) -> Int { try numerical { () throws(NumericalError) in try NumericalWork.sum(a,b) } }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(FrictionalImpulseFailure) { try numerical { () throws(NumericalError) in try work.chargeOperations(count) } }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(FrictionalImpulseFailure) { try numerical { () throws(NumericalError) in try work.requireStorage(count) } }
    static func iteration(_ work: inout NumericalWork) throws(FrictionalImpulseFailure) { try numerical { () throws(NumericalError) in try work.advanceIteration() } }
    static func dot(_ a: [Double], _ b: [Double], work: inout NumericalWork) throws(FrictionalImpulseFailure) -> Double {
        guard a.count == b.count else { throw FrictionalImpulseFailure(.invalidShape) }
        try charge(product(2,a.count),&work); var value=0.0
        for i in a.indices { value=try finite(value+a[i]*b[i]) }; return value
    }
    static func norm(_ values: [Double]) throws(FrictionalImpulseFailure) -> Double {
        let scale=values.reduce(0.0) { max($0,abs($1)) }
        if scale == 0 { return 0 }
        var sum=0.0; for value in values { sum=try finite(sum+(value/scale)*(value/scale)) }
        return try finite(scale*sum.squareRoot())
    }
    static func threshold(_ tolerance: NumericalTolerance, scale: Double) throws(FrictionalImpulseFailure) -> Double {
        try finite(tolerance.absolute+tolerance.relative*scale)
    }
    static func samePose(_ a: RigidTransform, _ b: RigidTransform, policy: HybridPolicy) throws(FrictionalImpulseFailure) -> Bool {
        guard try core({ () throws(CoreError) in try a.translation.subtracting(b.translation).magnitude() }) <= policy.lengthTolerance else { return false }
        for axis in [Vector3.unitX,Vector3.unitY,Vector3.unitZ] {
            if try core({ () throws(CoreError) in try a.transforming(direction:axis).subtracting(b.transforming(direction:axis)).magnitude() }) > policy.normalTolerance { return false }
        }; return true
    }
    static func components(_ vector: Vector3, basis: ContactBasis) throws(FrictionalImpulseFailure) -> [Double] {
        try core { () throws(CoreError) in [try basis.normal.dot(vector),try basis.firstTangent.dot(vector),try basis.secondTangent.dot(vector)] }
    }
    static func vector(_ values: [Double]) throws(FrictionalImpulseFailure) -> Vector3 {
        guard values.count == 3 else { throw FrictionalImpulseFailure(.invalidShape) }
        return try core { () throws(CoreError) in try Vector3(values[0],values[1],values[2]) }
    }
}
