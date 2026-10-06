#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct SealedLiquidLaw: Equatable, Sendable {
    public let referenceVolume: Double, area: Double, bulkModulus: Double
    public let referencePressure: Double, ambientPressure: Double, minimumStroke: Double, maximumStroke: Double
    public init(referenceVolume: Double, area: Double, bulkModulus: Double, referencePressure: Double,
                ambientPressure: Double, minimumStroke: Double, maximumStroke: Double) throws(ActuationError) {
        guard referenceVolume.isFinite, area.isFinite, bulkModulus.isFinite, referencePressure.isFinite,
              ambientPressure.isFinite, minimumStroke.isFinite, maximumStroke.isFinite,
              referenceVolume > 0, area > 0, bulkModulus > 0, referencePressure > 0, ambientPressure >= 0,
              minimumStroke <= 0, maximumStroke >= 0, minimumStroke < maximumStroke else { throw .invalidLaw }
        let low = referenceVolume + area * minimumStroke, high = referenceVolume + area * maximumStroke
        guard low.isFinite, high.isFinite, low > 0, high > 0 else { throw .invalidLaw }
        let lowPressure = referencePressure - bulkModulus * log1p(area * maximumStroke / referenceVolume)
        let highPressure = referencePressure - bulkModulus * log1p(area * minimumStroke / referenceVolume)
        guard lowPressure.isFinite, highPressure.isFinite, lowPressure > 0 else { throw .invalidLaw }
        self.referenceVolume = referenceVolume; self.area = area; self.bulkModulus = bulkModulus
        self.referencePressure = referencePressure; self.ambientPressure = ambientPressure
        self.minimumStroke = minimumStroke; self.maximumStroke = maximumStroke
    }
}
