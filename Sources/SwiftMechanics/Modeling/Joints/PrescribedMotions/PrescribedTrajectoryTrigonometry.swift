#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted trajectory scalar mathematics platform module is available.")
#endif

internal enum PrescribedTrajectoryTrigonometry {
    static func sine(_ value:Double) -> Double { sin(value) }
    static func cosine(_ value:Double) -> Double { cos(value) }
}
