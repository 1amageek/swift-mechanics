#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct PolytropicGasLaw: Equatable, Sendable {
    public let referenceVolume: Double, area: Double, exponent: Double, referencePressure: Double
    public let ambientPressure: Double, minimumStroke: Double, maximumStroke: Double
    public init(referenceVolume: Double, area: Double, exponent: Double, referencePressure: Double,
                ambientPressure: Double, minimumStroke: Double, maximumStroke: Double) throws(ActuationError) {
        guard referenceVolume.isFinite, area.isFinite, exponent.isFinite, referencePressure.isFinite,
              ambientPressure.isFinite, minimumStroke.isFinite, maximumStroke.isFinite,
              referenceVolume > 0, area > 0, exponent > 0, referencePressure > 0, ambientPressure >= 0,
              minimumStroke <= 0, maximumStroke >= 0, minimumStroke < maximumStroke else { throw .invalidLaw }
        let low = referenceVolume + area * minimumStroke, high = referenceVolume + area * maximumStroke
        guard low.isFinite, high.isFinite, low > 0, high > 0 else { throw .invalidLaw }
        self.referenceVolume = referenceVolume; self.area = area; self.exponent = exponent
        self.referencePressure = referencePressure; self.ambientPressure = ambientPressure
        self.minimumStroke = minimumStroke; self.maximumStroke = maximumStroke
    }
}
