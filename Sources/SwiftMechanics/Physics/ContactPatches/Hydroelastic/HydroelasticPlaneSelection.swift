public struct HydroelasticPlaneSelection: Sendable {
    public let representation: RigidPressurePlane
    public let expectedModelRevision: UInt64, expectedPlaneRevision: UInt64
    public let geometrySource: SourceProvenance, expectedGeometrySource: SourceProvenance
    public let sample: SourceProvenance
    public let sampleTimeSeconds: Double
    public init(representation: RigidPressurePlane, expectedModelRevision: UInt64, expectedPlaneRevision: UInt64,
                geometrySource: SourceProvenance, expectedGeometrySource: SourceProvenance,
                sample: SourceProvenance, sampleTimeSeconds: Double) throws(HydroelasticError) {
        guard sampleTimeSeconds.isFinite else { throw .invalidInput }
        self.representation=representation; self.expectedModelRevision=expectedModelRevision; self.expectedPlaneRevision=expectedPlaneRevision
        self.geometrySource=geometrySource; self.expectedGeometrySource=expectedGeometrySource
        self.sample=sample; self.sampleTimeSeconds=sampleTimeSeconds
    }
}
