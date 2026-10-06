public struct FieldAveragingPolicy: Equatable, Sendable {
    public enum Weighting: Equatable, Sendable { case referenceVolume, currentVolume }
    public enum MaterialMixing: Equatable, Sendable { case requireSameMaterial, explicitBlend }
    public let weighting: Weighting
    public let materialMixing: MaterialMixing
    public init(weighting: Weighting, materialMixing: MaterialMixing) {
        self.weighting = weighting; self.materialMixing = materialMixing
    }
}
