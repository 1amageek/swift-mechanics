internal enum URDFNumbers {
    static func scalar(_ text: String, at location: XMLLocation, work: inout URDFWork) throws(URDFFailure) -> Double {
        try work.charge(text.utf8.count, at: location)
        let bytes = text.utf8
        var offset = bytes.startIndex, hasDigit = false
        if offset < bytes.endIndex, bytes[offset] == 43 || bytes[offset] == 45 { offset = bytes.index(after: offset) }
        while offset < bytes.endIndex, bytes[offset] >= 48, bytes[offset] <= 57 {
            try work.charge(0, at: location); hasDigit = true; offset = bytes.index(after: offset)
        }
        if offset < bytes.endIndex, bytes[offset] == 46 {
            offset = bytes.index(after: offset)
            while offset < bytes.endIndex, bytes[offset] >= 48, bytes[offset] <= 57 {
                try work.charge(0, at: location); hasDigit = true; offset = bytes.index(after: offset)
            }
        }
        guard hasDigit else { throw URDFFailure(.invalid("decimal number"), at: location) }
        let mantissaEnd = offset
        if offset < bytes.endIndex, bytes[offset] == 101 || bytes[offset] == 69 {
            offset = bytes.index(after: offset)
            if offset < bytes.endIndex, bytes[offset] == 43 || bytes[offset] == 45 { offset = bytes.index(after: offset) }
            let start = offset
            while offset < bytes.endIndex, bytes[offset] >= 48, bytes[offset] <= 57 {
                try work.charge(0, at: location); offset = bytes.index(after: offset)
            }
            guard offset > start else { throw URDFFailure(.invalid("decimal exponent"), at: location) }
        }
        try work.charge(text.utf8.count, at: location)
        guard offset == bytes.endIndex, let value = Double(text), value.isFinite else {
            throw URDFFailure(.invalid("finite decimal number"), at: location)
        }
        try work.charge(text.utf8.count, at: location)
        if value == 0, bytes[..<mantissaEnd].contains(where: { $0 >= 49 && $0 <= 57 }) {
            throw URDFFailure(.invalid("decimal underflow"), at: location)
        }
        return value
    }
    static func vector(_ text: String, at location: XMLLocation, work: inout URDFWork) throws(URDFFailure) -> Vector3 {
        try work.charge(text.utf8.count, at: location)
        // Split is bounded by the input bytes before materializing substrings; reject excess components immediately.
        try work.allocate(4, stride: MemoryLayout<Substring>.stride, at: location)
        let parts = text.split(maxSplits: 3, omittingEmptySubsequences: true) { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }
        guard parts.count == 3 else { throw URDFFailure(.invalid("three-vector"), at: location) }
        try work.allocate(text.utf8.count, at: location)
        let x = try scalar(String(parts[0]), at: location, work: &work)
        let y = try scalar(String(parts[1]), at: location, work: &work)
        let z = try scalar(String(parts[2]), at: location, work: &work)
        do { return try Vector3(x, y, z) }
        catch { throw URDFFailure(.core(error), at: location) }
    }
}
