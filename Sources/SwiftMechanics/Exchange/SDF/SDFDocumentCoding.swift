public protocol SDFDocumentCoding: Sendable {
    func decode(bytes: [UInt8], options: SDFImportOptions, compilationPolicy: CompilationPolicy,
                work: inout SDFWork) throws(SDFError) -> SDFScene
    func encode(_ scene: SDFScene, expectedSource: SourceProvenance,
                work: inout SDFWork) throws(SDFError) -> [UInt8]
    func frameMotion(_ scopedName: String, in scene: SDFScene, expectedSource: SourceProvenance,
                     states: [KinematicState], work: inout SDFWork) throws(SDFError) -> FrameMotion
    func initialGravityLoads(in scene: SDFScene, expectedSource: SourceProvenance,
                             work: inout LoadWork) throws(SDFError) -> [GravityResponse]
}
