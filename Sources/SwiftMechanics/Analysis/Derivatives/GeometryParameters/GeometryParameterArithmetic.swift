internal enum GeometryParameterArithmetic {
    static func core<Value>(_ body: () throws(CoreError) -> Value) throws(GeometryParameterError) -> Value {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func finite(_ value: Double) throws(GeometryParameterError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func checkpoint(_ policy: GeometryParameterPolicy) throws(GeometryParameterError) {
        guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(GeometryParameterError) {
        guard !Task.isCancelled else { throw .cancelled }
        do throws(NumericalError) { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(GeometryParameterError) -> Int {
        do throws(NumericalError) { return try NumericalWork.product(a, b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(GeometryParameterError) -> Int {
        do throws(NumericalError) { return try NumericalWork.sum(a, b) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(GeometryParameterError) {
        do throws(NumericalError) { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func bytes(_ value: String, policy: GeometryParameterPolicy, work: inout NumericalWork) throws(GeometryParameterError) {
        for _ in value.utf8 { try checkpoint(policy); try charge(1, &work) }
    }
    static func scalar(_ value: Double, _ direction: Double = 0) throws(GeometryParameterError) -> DirectionalScalar {
        do throws(DerivativeError) { return try DirectionalScalar(value: value, direction: direction) } catch { throw .scalar(error) }
    }
    static func operation(_ operation: SmoothScalarOperation, _ left: DirectionalScalar, _ right: DirectionalScalar? = nil,
                          _ work: inout NumericalWork) throws(GeometryParameterError) -> DirectionalScalar {
        do throws(DerivativeError) { return try ExactScalarDifferentiator().evaluate(operation, left: left, right: right, work: &work) }
        catch { throw .scalar(error) }
    }
    static func add(_ a: GeometryVectorJet, _ b: GeometryVectorJet, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(6, &work)
        return try core { () throws(CoreError) in GeometryVectorJet(try a.value.adding(b.value), try a.direction.adding(b.direction)) }
    }
    static func subtract(_ a: GeometryVectorJet, _ b: GeometryVectorJet, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(6, &work)
        return try core { () throws(CoreError) in GeometryVectorJet(try a.value.subtracting(b.value), try a.direction.subtracting(b.direction)) }
    }
    static func scale(_ a: GeometryVectorJet, _ value: Double, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(6, &work)
        return try core { () throws(CoreError) in GeometryVectorJet(try a.value.scaled(by: value), try a.direction.scaled(by: value)) }
    }
    static func cross(_ a: GeometryVectorJet, _ b: GeometryVectorJet, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(30, &work)
        return try core { () throws(CoreError) in GeometryVectorJet(try a.value.cross(b.value), try a.direction.cross(b.value).adding(a.value.cross(b.direction))) }
    }
    static func apply(_ a: GeometryMatrixJet, _ b: GeometryVectorJet, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(48, &work)
        return try core { () throws(CoreError) in GeometryVectorJet(try a.value.applying(to: b.value), try a.direction.applying(to: b.value).adding(a.value.applying(to: b.direction))) }
    }
    static func multiply(_ a: GeometryMatrixJet, _ b: GeometryMatrixJet, _ work: inout NumericalWork) throws(GeometryParameterError) -> GeometryMatrixJet {
        try charge(144, &work)
        return try core { () throws(CoreError) in GeometryMatrixJet(try a.value.multiplied(by: b.value), try a.direction.multiplied(by: b.value).adding(a.value.multiplied(by: b.direction))) }
    }
    static func hat(_ a: Vector3, _ work: inout NumericalWork) throws(GeometryParameterError) -> Matrix3 {
        try charge(3, &work); return try core { () throws(CoreError) in try Matrix3(0, -a.z, a.y, a.z, 0, -a.x, -a.y, a.x, 0) }
    }
    static func normalize(_ raw: GeometryVectorJet, minimum: Double, work: inout NumericalWork) throws(GeometryParameterError) -> GeometryVectorJet {
        try charge(50, &work)
        let scale = max(abs(raw.value.x), max(abs(raw.value.y), abs(raw.value.z)))
        guard scale > 0 else { throw .derivativeUnavailable(.zeroOrBoundaryAxis) }
        let scaled = try core { () throws(CoreError) in try Vector3(raw.value.x / scale, raw.value.y / scale, raw.value.z / scale) }
        let norm = try core { () throws(CoreError) in try scaled.magnitude() }
        guard scale > minimum / norm else { throw .derivativeUnavailable(.zeroOrBoundaryAxis) }
        let unit = try core { () throws(CoreError) in try raw.value.normalized() }
        let d = try core { () throws(CoreError) in try Vector3(raw.direction.x / scale, raw.direction.y / scale, raw.direction.z / scale) }
        let direction = try core { () throws(CoreError) in try d.subtracting(unit.scaled(by: unit.dot(d))).scaled(by: 1 / norm) }
        return GeometryVectorJet(unit, direction)
    }
}
