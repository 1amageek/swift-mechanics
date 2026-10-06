public protocol SpatialBeamAssembling: Sendable {
    func assemble(_ beam: SpatialBeamDefinition, admission: SpatialBeamAdmission,
                  work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamAssembly
}
