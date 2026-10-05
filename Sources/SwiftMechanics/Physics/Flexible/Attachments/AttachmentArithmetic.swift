internal enum AttachmentArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(AttachmentError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(AttachmentError) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func surface<T>(_ body: () throws(DeformingContactError) -> T) throws(AttachmentError) -> T {
        do throws(DeformingContactError) { return try body() } catch { throw .surface(error) }
    }
    static func finite(_ value: Double) throws(AttachmentError) -> Double {
        guard value.isFinite else { throw .nonFinite }; return value
    }
    static func check(_ policy: AttachmentPolicy) throws(AttachmentError) {
        guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    static func charge(_ count: Int, _ policy: AttachmentPolicy, _ work: inout NumericalWork) throws(AttachmentError) {
        try check(policy)
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func text(_ value: String, _ policy: AttachmentPolicy, _ work: inout NumericalWork) throws(AttachmentError) {
        var count = 0
        for _ in value.utf8 {
            guard count < policy.maximumIdentifierBytes else { throw .capacityExceeded }
            try charge(1, policy, &work); count += 1
        }
        guard count > 0 else { throw .invalidInput }
    }
    static func storage(_ count: Int, _ policy: AttachmentPolicy, _ work: inout NumericalWork) throws(AttachmentError) {
        guard count <= policy.maximumScalars else { throw .capacityExceeded }
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func product(_ a: Int, _ b: Int) throws(AttachmentError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.product(a, b) }
    }
    static func sum(_ a: Int, _ b: Int) throws(AttachmentError) -> Int {
        try numerical { () throws(NumericalError) in try NumericalWork.sum(a, b) }
    }
}
