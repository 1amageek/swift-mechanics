internal enum HexahedralArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(HexahedralError) -> T {
        do { return try body() } catch { throw .core(error) }
    }

    static func charge(_ count: Int, _ work: inout NumericalWork) throws(HexahedralError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }

    static func checkpoint(_ isCancelled: @Sendable () -> Bool) throws(HexahedralError) {
        guard !Task.isCancelled, !isCancelled() else { throw .cancelled }
    }

    static func storage(_ count: Int, _ work: inout NumericalWork) throws(HexahedralError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }

    static func product(_ left: Int, _ right: Int) throws(HexahedralError) -> Int {
        do { return try NumericalWork.product(left, right) } catch { throw .numerical(error) }
    }

    static func sum(_ left: Int, _ right: Int) throws(HexahedralError) -> Int {
        do { return try NumericalWork.sum(left, right) } catch { throw .numerical(error) }
    }

    static func finite(_ value: Double) throws(HexahedralError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }

    static func component(_ vector: Vector3, _ axis: Int) -> Double {
        switch axis { case 0: return vector.x; case 1: return vector.y; default: return vector.z }
    }

    static func admit(_ text: String, isCancelled: @Sendable () -> Bool,
                      work: inout NumericalWork) throws(HexahedralError) {
        var iterator = text.utf8.makeIterator()
        while true {
            try checkpoint(isCancelled)
            // Reserve traversal and canonical equality units before advancing the borrowed view.
            try charge(2, &work)
            guard iterator.next() != nil else { return }
        }
    }

    static func same(_ left: EntityID, _ right: EntityID, isCancelled: @Sendable () -> Bool,
                     work: inout NumericalWork) throws(HexahedralError) -> Bool {
        try checkpoint(isCancelled)
        try charge(1, &work)
        guard left.kind == right.kind else { return false }
        try admit(left.key, isCancelled: isCancelled, work: &work)
        try admit(right.key, isCancelled: isCancelled, work: &work)
        try checkpoint(isCancelled)
        return left == right
    }

    static func same(_ left: SourceProvenance, _ right: SourceProvenance, isCancelled: @Sendable () -> Bool,
                     work: inout NumericalWork) throws(HexahedralError) -> Bool {
        try checkpoint(isCancelled)
        try charge(1, &work)
        guard left.revision == right.revision else { return false }
        try admit(left.source, isCancelled: isCancelled, work: &work)
        try admit(right.source, isCancelled: isCancelled, work: &work)
        try checkpoint(isCancelled)
        return left == right
    }
}
