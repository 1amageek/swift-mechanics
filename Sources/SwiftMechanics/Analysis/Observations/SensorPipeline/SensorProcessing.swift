public struct SensorProcessing: Equatable, Sendable {
    public let bias: Double
    public let noiseHalfWidth: Double
    public let quantizationStep: Double?
    public let quantizationOrigin: Double
    public let saturationLower: Double?
    public let saturationUpper: Double?
    public let dropoutProbability: Double
    public let delaySeconds: Double

    public init(bias: Double = 0, noiseHalfWidth: Double = 0, quantizationStep: Double? = nil,
                quantizationOrigin: Double = 0, saturationLower: Double? = nil, saturationUpper: Double? = nil,
                dropoutProbability: Double = 0, delaySeconds: Double = 0) throws(SensorPipelineFailure) {
        guard bias.isFinite, noiseHalfWidth.isFinite, noiseHalfWidth >= 0, quantizationOrigin.isFinite,
              dropoutProbability.isFinite, (0...1).contains(dropoutProbability), delaySeconds.isFinite, delaySeconds >= 0,
              quantizationStep == nil || (quantizationStep!.isFinite && quantizationStep! > 0),
              (saturationLower == nil) == (saturationUpper == nil) else { throw .invalidDefinition }
        if let lower = saturationLower, let upper = saturationUpper {
            guard lower.isFinite, upper.isFinite, lower <= upper else { throw .invalidDefinition }
        }
        self.bias = bias; self.noiseHalfWidth = noiseHalfWidth; self.quantizationStep = quantizationStep
        self.quantizationOrigin = quantizationOrigin; self.saturationLower = saturationLower; self.saturationUpper = saturationUpper
        self.dropoutProbability = dropoutProbability; self.delaySeconds = delaySeconds
    }
    internal func apply(_ raw: Double, noise: Double) throws(SensorPipelineFailure) -> (Double, Bool) {
        var value = raw + bias
        guard value.isFinite else { throw .nonfinite }
        value += (2 * noise - 1) * noiseHalfWidth
        guard value.isFinite else { throw .nonfinite }
        if let step = quantizationStep {
            let bin = (value - quantizationOrigin) / step
            guard bin.isFinite else { throw .nonfinite }
            value = bin.rounded(.toNearestOrEven) * step + quantizationOrigin
            guard value.isFinite else { throw .nonfinite }
        }
        let before = value
        if let lower = saturationLower, let upper = saturationUpper { value = min(upper, max(lower, value)) }
        return (value, value != before)
    }
}
