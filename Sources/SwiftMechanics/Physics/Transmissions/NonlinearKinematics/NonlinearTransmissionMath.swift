#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

internal enum NonlinearTransmissionMath {
    static func finite(_ value: Double) throws(NonlinearTransmissionError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "nonlinearTransmissionArithmetic") }
        return value
    }
    static func cycloidalFraction(_ u: Double) -> Double {
        let z=2*Double.pi*u
        if abs(z) >= 0.125 { return u-sin(z)/(2*Double.pi) }
        // Bounded expansion of 1-sinc(z) avoids cancellation of tiny positive lift.
        var term=z*z/6, sum=term
        for n in 2...12 { term *= -z*z/Double((2*n)*(2*n+1)); sum += term }
        return u*sum
    }
}
