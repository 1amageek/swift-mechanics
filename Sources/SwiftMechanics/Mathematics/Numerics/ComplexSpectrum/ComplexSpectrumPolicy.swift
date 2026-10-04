public struct ComplexSpectrumPolicy: Sendable {
    public let maximumDimension: Int, maximumQRIterations: Int
    public let deflationTolerance: Double, eigenvectorPivotThreshold: Double, originalResidualTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumDimension: Int, maximumQRIterations: Int, deflationTolerance: Double,
                eigenvectorPivotThreshold: Double, originalResidualTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool) throws(ComplexSpectrumError) {
        guard maximumDimension>0,maximumQRIterations>=0,deflationTolerance.isFinite,deflationTolerance>0,
            eigenvectorPivotThreshold.isFinite,eigenvectorPivotThreshold>0,originalResidualTolerance.isFinite,originalResidualTolerance>0 else { throw .invalidPolicy }
        self.maximumDimension=maximumDimension;self.maximumQRIterations=maximumQRIterations
        self.deflationTolerance=deflationTolerance;self.eigenvectorPivotThreshold=eigenvectorPivotThreshold
        self.originalResidualTolerance=originalResidualTolerance;self.isCancelled=isCancelled
    }
}
