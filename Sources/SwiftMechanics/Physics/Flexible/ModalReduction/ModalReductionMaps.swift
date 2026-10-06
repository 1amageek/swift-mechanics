public struct ModalReductionMaps: Sendable {
    public let identity: String
    public let inputDimensions: [PhysicalDimension]
    /// Row-major source-coordinate by input generalized effort map.
    public let inputMap: [Double]
    public let inputCoefficientDimensions: [PhysicalDimension]
    public let interfaceDimensions: [PhysicalDimension]
    /// Row-major interface displacement by unfixed source coordinate map.
    public let interfaceMap: [Double]
    public let interfaceCoefficientDimensions: [PhysicalDimension]
    public init(identity: String, inputDimensions: [PhysicalDimension], inputMap: [Double],
                inputCoefficientDimensions: [PhysicalDimension], interfaceDimensions: [PhysicalDimension],
                interfaceMap: [Double], interfaceCoefficientDimensions: [PhysicalDimension]) {
        self.identity=identity; self.inputDimensions=inputDimensions; self.inputMap=inputMap
        self.inputCoefficientDimensions=inputCoefficientDimensions; self.interfaceDimensions=interfaceDimensions
        self.interfaceMap=interfaceMap; self.interfaceCoefficientDimensions=interfaceCoefficientDimensions
    }
}
