internal enum NativeUTF8Validation {
    static func validate(bytes:[UInt8],range:Range<Int>) throws(ExchangeError) {
        var i=range.lowerBound
        while i < range.upperBound {
            let first=bytes[i]
            if first < 0x80 { i += 1;continue }
            let width:Int,secondMinimum:UInt8,secondMaximum:UInt8
            switch first {
            case 0xc2...0xdf:width=2;secondMinimum=0x80;secondMaximum=0xbf
            case 0xe0:width=3;secondMinimum=0xa0;secondMaximum=0xbf
            case 0xe1...0xec,0xee...0xef:width=3;secondMinimum=0x80;secondMaximum=0xbf
            case 0xed:width=3;secondMinimum=0x80;secondMaximum=0x9f
            case 0xf0:width=4;secondMinimum=0x90;secondMaximum=0xbf
            case 0xf1...0xf3:width=4;secondMinimum=0x80;secondMaximum=0xbf
            case 0xf4:width=4;secondMinimum=0x80;secondMaximum=0x8f
            default:throw .invalidUTF8(offset:i)
            }
            guard range.upperBound-i >= width,bytes[i+1] >= secondMinimum,bytes[i+1] <= secondMaximum else { throw .invalidUTF8(offset:i) }
            for j in 2..<width { guard bytes[i+j] >= 0x80,bytes[i+j] <= 0xbf else { throw .invalidUTF8(offset:i+j) } }
            i += width
        }
    }
}
