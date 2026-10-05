internal enum MJCFArithmetic {
    static func sum(_ a: Int, _ b: Int) throws(MJCFError) -> Int {
        guard a >= 0, b >= 0 else { throw .arithmeticOverflow }
        let (v, overflow) = a.addingReportingOverflow(b); guard !overflow else { throw .arithmeticOverflow }; return v
    }
    static func product(_ a: Int, _ b: Int) throws(MJCFError) -> Int {
        guard a >= 0, b >= 0 else { throw .arithmeticOverflow }
        let (v, overflow) = a.multipliedReportingOverflow(by: b); guard !overflow else { throw .arithmeticOverflow }; return v
    }
    static func finite(_ value: Double) throws(MJCFError) -> Double {
        guard value.isFinite else { throw .nonFiniteArithmetic }; return value
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(MJCFError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func id(_ kind: EntityKind, _ key: String, work: inout MJCFWork) throws(MJCFError) -> EntityID {
        try work.text(key)
        do { return try EntityID(kind: kind, key: key) } catch { throw .model(error) }
    }
    static func numbers(_ text: String, maximum: Int, node: Int, work: inout MJCFWork) throws(MJCFError) -> [Double] {
        var result: [Double] = [], token = ""
        for byte in text.utf8 {
            try work.charge(1)
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 {
                if !token.isEmpty { try append(token, to: &result, maximum: maximum, node: node, work: &work); token = "" }
            } else {
                guard (48...57).contains(byte) || byte == 43 || byte == 45 || byte == 46 || byte == 69 || byte == 101 else { throw .invalidInput(node: node, field: "number") }
                try work.allocate(1); token.append(Character(UnicodeScalar(byte)))
            }
        }
        if !token.isEmpty { try append(token, to: &result, maximum: maximum, node: node, work: &work) }
        return result
    }
    private static func append(_ token: String, to result: inout [Double], maximum: Int, node: Int, work: inout MJCFWork) throws(MJCFError) {
        guard result.count < maximum, let value = Double(token), value.isFinite else { throw .invalidInput(node: node, field: "number") }
        try work.allocate(MemoryLayout<Double>.stride); result.append(value)
    }
}
