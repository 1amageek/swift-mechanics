public struct HydroelasticPolicy: Sendable {
    public let maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumMetadataBytes: Int
    public let maximumVertices: Int, maximumTriangles: Int
    public let maximumPressure: Double, minimumVolumeRatio: Double, inverseRelativeTolerance: Double
    public let minimumTriangleArea: Double, distanceTolerance: Double, barycentricTolerance: Double
    public let normalTolerance: Double, pressureTolerance: Double, gradientTolerance: Double
    public let forceScale: Double, momentScale: Double, powerScale: Double, residualTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumMetadataBytes: Int,
                maximumVertices: Int, maximumTriangles: Int, maximumPressure: Double, minimumVolumeRatio: Double,
                inverseRelativeTolerance: Double, minimumTriangleArea: Double, distanceTolerance: Double,
                barycentricTolerance: Double, normalTolerance: Double, pressureTolerance: Double, gradientTolerance: Double,
                forceScale: Double, momentScale: Double, powerScale: Double, residualTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(HydroelasticError) {
        guard maximumNodes > 0, maximumCells > 0, maximumMaterials > 0, maximumMetadataBytes > 0,
              maximumVertices > 0, maximumTriangles > 0 else { throw .invalidInput }
        for value in [maximumPressure,minimumVolumeRatio,inverseRelativeTolerance,minimumTriangleArea,distanceTolerance,
                      barycentricTolerance,normalTolerance,pressureTolerance,gradientTolerance,forceScale,momentScale,powerScale] {
            guard value.isFinite, value > 0 else { throw .invalidInput }
        }
        guard inverseRelativeTolerance < 1, barycentricTolerance < 1, normalTolerance < 1,
              residualTolerance.isFinite, residualTolerance >= 0 else { throw .invalidInput }
        self.maximumNodes=maximumNodes; self.maximumCells=maximumCells; self.maximumMaterials=maximumMaterials
        self.maximumMetadataBytes=maximumMetadataBytes; self.maximumVertices=maximumVertices; self.maximumTriangles=maximumTriangles
        self.maximumPressure=maximumPressure; self.minimumVolumeRatio=minimumVolumeRatio; self.inverseRelativeTolerance=inverseRelativeTolerance
        self.minimumTriangleArea=minimumTriangleArea; self.distanceTolerance=distanceTolerance; self.barycentricTolerance=barycentricTolerance
        self.normalTolerance=normalTolerance; self.pressureTolerance=pressureTolerance; self.gradientTolerance=gradientTolerance
        self.forceScale=forceScale; self.momentScale=momentScale; self.powerScale=powerScale; self.residualTolerance=residualTolerance
        self.isCancelled=isCancelled
    }
}
