public struct IdentificationWorkspace: Sendable {
    internal var design: [Double] = []
    internal var offset: [Double] = []
    internal var physicalResiduals: [Double] = []
    internal var information: [Double] = []
    internal var covariance: [Double] = []
    public init() {}
}
