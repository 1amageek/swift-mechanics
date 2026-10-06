internal enum ShellArithmetic {
    static func finite(_ value: Double) throws(ShellError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
    static func positive(_ value: Double) throws(ShellError) -> Double {
        guard value.isFinite, value > 0 else { throw .nonFiniteResult }
        return value
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ShellError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(ShellError) -> T {
        do { return try body() } catch { throw .material(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ShellError) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func check(_ admission: ShellAdmission) throws(ShellError) {
        guard !Task.isCancelled, !admission.isCancelled() else { throw .cancelled }
    }
    static func charge(_ operations: Int, _ work: inout NumericalWork) throws(ShellError) {
        do { try work.chargeOperations(operations) } catch { throw .numerical(error) }
    }
    static func metadata(_ value: String, byteCount: inout Int, admission: ShellAdmission,
                         work: inout NumericalWork) throws(ShellError) {
        for _ in value.utf8 {
            try check(admission)
            guard byteCount < admission.maximumMetadataBytes else { throw .capacityExceeded }
            try charge(1, &work)
            byteCount += 1
        }
    }
}
