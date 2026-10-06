internal enum FieldOutputArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(FieldOutputError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(FieldOutputError) -> T {
        do throws(MaterialError) { return try body() } catch { throw .material(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(FieldOutputError) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(FieldOutputError) -> Double {
        guard value.isFinite else { throw .nonFinite }; return value
    }
    static func check(_ policy: FieldOutputPolicy) throws(FieldOutputError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ policy: FieldOutputPolicy, _ work: inout NumericalWork) throws(FieldOutputError) {
        try check(policy); try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func text(_ text: String, _ policy: FieldOutputPolicy, _ work: inout NumericalWork) throws(FieldOutputError) {
        var count = 0
        for _ in text.utf8 {
            guard count < policy.maximumIdentifierBytes else { throw .capacityExceeded }
            try charge(1, policy, &work); count += 1
        }
        guard count > 0 else { throw .invalidInput }
    }
    static func product(_ a: Int, _ b: Int) throws(FieldOutputError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a, b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(FieldOutputError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a, b) }
    }
    static func storage(_ count: Int, _ policy: FieldOutputPolicy, _ work: inout NumericalWork) throws(FieldOutputError) {
        guard count <= policy.maximumScalars else { throw .capacityExceeded }
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func outer(_ a: Vector3, _ b: Vector3) throws(FieldOutputError) -> Matrix3 {
        try core { () throws(CoreError) in try Matrix3(a.x*b.x,a.x*b.y,a.x*b.z,a.y*b.x,a.y*b.y,a.y*b.z,a.z*b.x,a.z*b.y,a.z*b.z) }
    }
    static func contracted(_ a: Matrix3, _ b: Matrix3) throws(FieldOutputError) -> Double {
        try finite(a.m00*b.m00+a.m01*b.m01+a.m02*b.m02+a.m10*b.m10+a.m11*b.m11+a.m12*b.m12+a.m20*b.m20+a.m21*b.m21+a.m22*b.m22)
    }
    static func gradient(_ reference: ReferenceTetrahedron, _ index: Int) throws(FieldOutputError) -> Vector3 {
        switch index {
        case 0: reference.gradient0
        case 1: reference.gradient1
        case 2: reference.gradient2
        case 3: reference.gradient3
        default: throw .invalidLocation
        }
    }
}
