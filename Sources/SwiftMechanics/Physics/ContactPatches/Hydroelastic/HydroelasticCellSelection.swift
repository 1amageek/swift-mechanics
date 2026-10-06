/// Explicit caller-owned current sample and selected cell, without a runtime admission token.
public struct HydroelasticCellSelection: Sendable {
    public let representation: PressureBody
    public let cellIdentifier: UInt64
    public let expectedModelRevision: UInt64, expectedMeshRevision: UInt64, expectedPressureRevision: UInt64
    public let expectedMeshSource: SourceProvenance, expectedCellSource: SourceProvenance
    public let calibration: HydroelasticCalibration
    public let expectedCalibrationSource: SourceProvenance
    public let sample: SourceProvenance
    public let sampleTimeSeconds: Double
    public init(representation: PressureBody, cellIdentifier: UInt64, expectedModelRevision: UInt64,
                expectedMeshRevision: UInt64, expectedPressureRevision: UInt64, expectedMeshSource: SourceProvenance,
                expectedCellSource: SourceProvenance, calibration: HydroelasticCalibration,
                expectedCalibrationSource: SourceProvenance, sample: SourceProvenance, sampleTimeSeconds: Double) throws(HydroelasticError) {
        guard sampleTimeSeconds.isFinite else { throw .invalidInput }
        self.representation=representation; self.cellIdentifier=cellIdentifier; self.expectedModelRevision=expectedModelRevision
        self.expectedMeshRevision=expectedMeshRevision; self.expectedPressureRevision=expectedPressureRevision
        self.expectedMeshSource=expectedMeshSource; self.expectedCellSource=expectedCellSource
        self.calibration=calibration; self.expectedCalibrationSource=expectedCalibrationSource
        self.sample=sample; self.sampleTimeSeconds=sampleTimeSeconds
    }
}
