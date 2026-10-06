public protocol SpatialBeamEvaluating: Sendable {
    func evaluate(_ assembly: SpatialBeamAssembly, state: SpatialBeamState,
                  admission: SpatialBeamAdmission, work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamResponse
    func field(_ assembly: SpatialBeamAssembly, state: SpatialBeamState, location: SpatialBeamLocation,
               stress: SpatialBeamStressRequest, admission: SpatialBeamAdmission,
               work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamField
}
