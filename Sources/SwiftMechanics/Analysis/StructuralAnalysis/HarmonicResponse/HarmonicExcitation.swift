public struct HarmonicExcitation: Sendable {
    public let identity: String
    public let angularFrequency: Double
    public let maximumAngularFrequency: Double
    public let maximumNormalizedAmplitude: Double
    public let realEffort: [Double]
    public let imaginaryEffort: [Double]
    public let outputMap: [Double]
    public let outputDimensions: [PhysicalDimension]
    public init(identity: String, angularFrequency: Double, maximumAngularFrequency: Double, maximumNormalizedAmplitude: Double,
                realEffort: [Double], imaginaryEffort: [Double], outputMap: [Double], outputDimensions: [PhysicalDimension]) {
        self.identity=identity;self.angularFrequency=angularFrequency;self.maximumAngularFrequency=maximumAngularFrequency
        self.maximumNormalizedAmplitude=maximumNormalizedAmplitude;self.realEffort=realEffort;self.imaginaryEffort=imaginaryEffort
        self.outputMap=outputMap;self.outputDimensions=outputDimensions
    }
}
