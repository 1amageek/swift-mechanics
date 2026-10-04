#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

internal enum ScalarMath {
    static func sine(_ value: Double) -> Double { sin(value) }
    static func cosine(_ value: Double) -> Double { cos(value) }
    static func angle(y: Double, x: Double) -> Double { atan2(y, x) }
    static func norm(_ x: Double, _ y: Double) -> Double { hypot(x, y) }
}
