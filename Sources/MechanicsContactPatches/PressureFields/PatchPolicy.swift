public struct PatchPolicy: Sendable {
    public let maximumNodes: Int, maximumCells: Int, maximumTriangles: Int
    public let expectedModelRevision: UInt64, expectedMeshRevision: UInt64, expectedPressureRevision: UInt64, expectedPlaneRevision: UInt64
    public let maximumPressure: Double, minimumDeterminant: Double, minimumTriangleArea: Double, planeDistanceTolerance: Double, normalTolerance: Double
    public let forceScale: Double, momentScale: Double, powerScale: Double, residualTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumNodes: Int, maximumCells: Int, maximumTriangles: Int, expectedModelRevision: UInt64, expectedMeshRevision: UInt64,
                expectedPressureRevision: UInt64, expectedPlaneRevision: UInt64, maximumPressure: Double, minimumDeterminant: Double,
                minimumTriangleArea: Double, planeDistanceTolerance: Double, normalTolerance: Double, forceScale: Double, momentScale: Double,
                powerScale: Double, residualTolerance: Double, isCancelled: @escaping @Sendable () -> Bool = {false}) throws(PatchError) {
        guard maximumNodes > 0, maximumCells > 0, maximumTriangles > 0, maximumPressure.isFinite, maximumPressure > 0,
            minimumDeterminant.isFinite, minimumDeterminant > 0, minimumTriangleArea.isFinite, minimumTriangleArea > 0,
            planeDistanceTolerance.isFinite, planeDistanceTolerance > 0, normalTolerance.isFinite, normalTolerance > 0, normalTolerance < 1,
            forceScale.isFinite, forceScale > 0, momentScale.isFinite, momentScale > 0, powerScale.isFinite, powerScale > 0,
            residualTolerance.isFinite, residualTolerance >= 0 else { throw .invalidInput }
        self.maximumNodes=maximumNodes; self.maximumCells=maximumCells; self.maximumTriangles=maximumTriangles
        self.expectedModelRevision=expectedModelRevision; self.expectedMeshRevision=expectedMeshRevision; self.expectedPressureRevision=expectedPressureRevision; self.expectedPlaneRevision=expectedPlaneRevision
        self.maximumPressure=maximumPressure; self.minimumDeterminant=minimumDeterminant; self.minimumTriangleArea=minimumTriangleArea
        self.planeDistanceTolerance=planeDistanceTolerance; self.normalTolerance=normalTolerance; self.forceScale=forceScale; self.momentScale=momentScale
        self.powerScale=powerScale; self.residualTolerance=residualTolerance; self.isCancelled=isCancelled
    }
}
