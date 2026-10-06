public struct GeometryParameterBinding: Equatable, Sendable {
    public let parameterID: UInt64
    public let originalValue: Double
    public let dimension: PhysicalDimension
    public let modelSource: SourceProvenance
    public let parameterSource: SourceProvenance
    public let treeRevision: UInt64
    public let target: GeometryParameterTarget
    public let chart: GeometryParameterChart
    public init(parameterID: UInt64, originalValue: Double, dimension: PhysicalDimension,
                modelSource: SourceProvenance, parameterSource: SourceProvenance, treeRevision: UInt64,
                target: GeometryParameterTarget, chart: GeometryParameterChart) throws(GeometryParameterError) {
        guard originalValue.isFinite, dimension == chart.dimension else { throw .invalidInput }
        self.parameterID = parameterID; self.originalValue = originalValue; self.dimension = dimension
        self.modelSource = modelSource; self.parameterSource = parameterSource; self.treeRevision = treeRevision
        self.target = target; self.chart = chart
    }
}
