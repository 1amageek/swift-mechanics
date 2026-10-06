internal enum SDFNumbers {
    static func values(_ text: String, maximum: Int, node: Int, work: inout SDFWork) throws(SDFError) -> [Double] {
        var result: [Double] = [], token: [UInt8] = []
        for byte in text.utf8 {
            try work.charge(2)
            if byte == 32 || byte == 10 || byte == 13 || byte == 9 {
                if !token.isEmpty {
                    guard result.count < maximum else { throw .invalidInput(node: node) }
                    result.append(try number(token, node: node, work: &work)); token.removeAll(keepingCapacity: true)
                }
            } else {
                guard token.count < work.policy.maximumTokenBytes else { throw .invalidInput(node: node) }
                token.append(byte)
            }
        }
        if !token.isEmpty {
            guard result.count < maximum else { throw .invalidInput(node: node) }
            result.append(try number(token, node: node, work: &work))
        }
        return result
    }
    private static func number(_ token: [UInt8], node: Int, work: inout SDFWork) throws(SDFError) -> Double {
        var digits = 0, point = false, exponent = false, exponentDigits = 0, previous: UInt8?
        var nonzeroMantissa = false
        for byte in token {
            try work.charge(2)
            switch byte {
            case 48...57:
                if exponent { exponentDigits += 1 }
                else { digits += 1; nonzeroMantissa = nonzeroMantissa || byte != 48 }
            case 43, 45:
                guard previous == nil || previous == 101 || previous == 69 else { throw .invalidInput(node: node) }
            case 46:
                guard !point, !exponent else { throw .invalidInput(node: node) }; point = true
            case 101, 69:
                guard !exponent, digits > 0 else { throw .invalidInput(node: node) }; exponent = true
            default: throw .invalidInput(node: node)
            }
            previous = byte
        }
        guard digits > 0, !exponent || exponentDigits > 0,
              let value = Double(String(decoding: token, as: UTF8.self)), value.isFinite,
              value != 0 || !nonzeroMantissa else { throw .invalidInput(node: node) }
        return value
    }
    static func word(_ text: String, node: Int, work: inout SDFWork) throws(SDFError) -> String {
        var token: [UInt8] = [], trailing = false
        for byte in text.utf8 {
            try work.charge(2)
            if byte == 32 || byte == 10 || byte == 13 || byte == 9 {
                if !token.isEmpty { trailing = true }
            } else {
                guard !trailing, token.count < work.policy.maximumTokenBytes else { throw .invalidInput(node: node) }
                token.append(byte)
            }
        }
        guard !token.isEmpty else { throw .invalidInput(node: node) }
        return String(decoding: token, as: UTF8.self)
    }
}
