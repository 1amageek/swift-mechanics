internal enum XMLGrammar {
    static func character(_ value: UInt32) -> Bool {
        value == 9 || value == 10 || value == 13 || (value >= 0x20 && value <= 0xd7ff)
        || (value >= 0xe000 && value <= 0xfffd) || (value >= 0x10000 && value <= 0x10ffff)
    }
    static func nameStart(_ value: UInt32) -> Bool {
        value == 95 || (65...90).contains(value) || (97...122).contains(value)
        || (0xc0...0xd6).contains(value) || (0xd8...0xf6).contains(value)
        || (0xf8...0x2ff).contains(value) || (0x370...0x37d).contains(value)
        || (0x37f...0x1fff).contains(value) || (0x200c...0x200d).contains(value)
        || (0x2070...0x218f).contains(value) || (0x2c00...0x2fef).contains(value)
        || (0x3001...0xd7ff).contains(value) || (0xf900...0xfdcf).contains(value)
        || (0xfdf0...0xfffd).contains(value) || (0x10000...0xeffff).contains(value)
    }
    static func nameContinuation(_ value: UInt32) -> Bool {
        nameStart(value) || value == 45 || value == 46 || (48...57).contains(value)
        || value == 0xb7 || (0x300...0x36f).contains(value) || (0x203f...0x2040).contains(value)
    }
    static func whitespace(_ value: UInt32) -> Bool { value == 32 || value == 9 || value == 10 || value == 13 }
    static func same(_ a: String, _ b: String, work: inout XMLWork, at location: XMLLocation) throws(XMLFailure) -> Bool {
        var left = a.utf8.makeIterator(), right = b.utf8.makeIterator()
        while true {
            try work.charge(1, at: location)
            let x = left.next(), y = right.next()
            if x != y { return false }
            if x == nil { return true }
        }
    }
    static func validateName(_ name: String, work: inout XMLWork, at location: XMLLocation) throws(XMLFailure) {
        var first = true
        for scalar in name.unicodeScalars {
            try work.charge(1, at: location)
            if scalar.value == 58 { throw XMLFailure(.unsupportedNamespaces, at: location) }
            guard first ? nameStart(scalar.value) : nameContinuation(scalar.value) else { throw XMLFailure(.invalidName, at: location) }
            first = false
        }
        guard !first else { throw XMLFailure(.invalidName, at: location) }
    }
}
