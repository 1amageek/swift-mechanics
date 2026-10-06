internal struct XMLCursor {
    let bytes: [UInt8]
    var work: XMLWork
    var offset = 0
    var line = 1
    var column = 1
    var previousCR = false
    var location: XMLLocation { XMLLocation(byteOffset: offset, line: line, byteColumn: column) }
    var ended: Bool { offset == bytes.count }
    func starts(_ token: String) -> Bool {
        var index = offset
        for byte in token.utf8 {
            guard index < bytes.count, bytes[index] == byte else { return false }
            index += 1
        }
        return true
    }
    mutating func expect(_ token: String) throws(XMLFailure) {
        guard starts(token) else { throw XMLFailure(ended ? .unexpectedEnd : .malformedSyntax, at: location) }
        for _ in token.utf8 { try advanceByte() }
    }
    mutating func advanceByte() throws(XMLFailure) {
        guard !ended else { throw XMLFailure(.unexpectedEnd, at: location) }
        try work.charge(1, at: location)
        let value = bytes[offset]; offset += 1
        if value == 13 { line = try diagnosticIncrement(line); column = 1 }
        else if value == 10 { if !previousCR { line = try diagnosticIncrement(line) }; column = 1 }
        else { column = try diagnosticIncrement(column) }
        previousCR = value == 13
    }
    func diagnosticIncrement(_ value: Int) throws(XMLFailure) -> Int {
        let (next, overflow) = value.addingReportingOverflow(1)
        guard !overflow else { throw XMLFailure(.arithmeticOverflow, at: location) }
        return next
    }
    func scalar() throws(XMLFailure) -> (UInt32, Int) {
        guard !ended else { throw XMLFailure(.unexpectedEnd, at: location) }
        let first = bytes[offset]
        let width: Int, low: UInt8, high: UInt8
        var value: UInt32
        switch first {
        case 0...0x7f: width = 1; low = 0; high = 0; value = UInt32(first)
        case 0xc2...0xdf: width = 2; low = 0x80; high = 0xbf; value = UInt32(first & 0x1f)
        case 0xe0: width = 3; low = 0xa0; high = 0xbf; value = UInt32(first & 0xf)
        case 0xe1...0xec, 0xee...0xef: width = 3; low = 0x80; high = 0xbf; value = UInt32(first & 0xf)
        case 0xed: width = 3; low = 0x80; high = 0x9f; value = UInt32(first & 0xf)
        case 0xf0: width = 4; low = 0x90; high = 0xbf; value = UInt32(first & 7)
        case 0xf1...0xf3: width = 4; low = 0x80; high = 0xbf; value = UInt32(first & 7)
        case 0xf4: width = 4; low = 0x80; high = 0x8f; value = UInt32(first & 7)
        default: throw XMLFailure(.invalidUTF8, at: location)
        }
        guard bytes.count - offset >= width else { throw XMLFailure(.invalidUTF8, at: location) }
        if width > 1 {
            guard bytes[offset + 1] >= low, bytes[offset + 1] <= high else { throw XMLFailure(.invalidUTF8, at: location) }
            for index in 1..<width {
                let byte = bytes[offset + index]
                guard byte >= 0x80, byte <= 0xbf else { throw XMLFailure(.invalidUTF8, at: location) }
                value = (value << 6) | UInt32(byte & 0x3f)
            }
        }
        guard XMLGrammar.character(value) else { throw XMLFailure(.invalidCharacter, at: location) }
        return (value, width)
    }
    mutating func takeScalar(normalize: Bool = false) throws(XMLFailure) -> UInt32 {
        let (value, width) = try scalar()
        for _ in 0..<width { try advanceByte() }
        if normalize && value == 13 {
            if starts("\n") { try advanceByte() }
            return 10
        }
        return value
    }
    mutating func whitespace() throws(XMLFailure) -> Bool {
        var consumed = false
        while !ended {
            let value = try scalar().0
            if !XMLGrammar.whitespace(value) { break }
            _ = try takeScalar(); consumed = true
        }
        return consumed
    }
    mutating func append(_ value: UInt32, to string: inout String) throws(XMLFailure) {
        guard let scalar = Unicode.Scalar(value), XMLGrammar.character(value) else { throw XMLFailure(.invalidCharacter, at: location) }
        let width = value < 0x80 ? 1 : value < 0x800 ? 2 : value < 0x10000 ? 3 : 4
        try work.payload(width, at: location)
        string.unicodeScalars.append(scalar)
    }
}
